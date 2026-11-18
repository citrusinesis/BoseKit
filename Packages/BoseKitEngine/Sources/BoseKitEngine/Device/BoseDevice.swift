public actor BoseDevice {
    public nonisolated let profile: DeviceProfile
    private let session: BMAPSession
    private var transactionActive = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var rememberedCNC: [UInt8: UInt8] = [:]
    private var knownModes: [ModeConfiguration]?

    private init(profile: DeviceProfile, session: BMAPSession) {
        self.profile = profile
        self.session = session
    }

    public static func connect(profile: DeviceProfile, transport: any BMAPTransport) async throws -> BoseDevice {
        let session = try await BMAPSession.connect(transport: transport)
        do {
            for packet in profile.initialization {
                _ = try await session.execute(BMAPCommand(packet: packet, decode: { $0 }))
            }
            return BoseDevice(profile: profile, session: session)
        } catch {
            await session.close()
            throw error
        }
    }

    public func events() async -> AsyncStream<BMAPPacket> { await session.events() }
    public func close() async { await session.close() }

    public func read<V, I>(_ feature: BoseFeature<V, I>) async throws -> V {
        try await transaction { device in try await device.readValue(feature) }
    }

    @discardableResult
    public func write<V, I>(
        _ feature: BoseFeature<V, I>, value: I,
        verify: (@Sendable (V, I) -> Bool)? = nil
    ) async throws -> V {
        try await transaction { device in
            let actual = try await device.writeValue(feature, value)
            if let verify, !verify(actual, value) { throw BoseError.verificationFailed(feature.id.rawValue) }
            return actual
        }
    }

    private func transaction<T: Sendable>(
        _ body: (isolated BoseDevice) async throws -> T
    ) async throws -> T {
        if transactionActive {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            transactionActive = true
        }
        defer {
            if waiters.isEmpty { transactionActive = false }
            else { waiters.removeFirst().resume() }
        }
        try Task.checkCancellation()
        return try await body(self)
    }

    private func check(_ id: FeatureID, _ access: FeatureAccess) throws {
        guard profile.supports(id, access: access) else { throw BoseError.unsupported(id.rawValue) }
    }

    private func payload(_ address: BMAPAddress, operation: BMAPOperator = .get,
                 bytes: [UInt8] = []) async throws -> [UInt8] {
        let packet = try BMAPPacket(address: address, operation: operation, payload: bytes)
        return try await session.execute(BMAPCommand(packet: packet) { packets in
            guard let reply = packets.last else { throw BoseError.invalidPayload("Missing reply") }
            return reply.payload
        })
    }

    private func readValue<V, I>(_ feature: BoseFeature<V, I>) async throws -> V {
        try check(feature.id, .read)
        return try feature.decode(await payload(feature.address), profile)
    }

    private func writeValue<V, I>(_ feature: BoseFeature<V, I>, _ value: I) async throws -> V {
        try check(feature.id, .write)
        let bytes = try feature.encode(value, profile)
        _ = try await payload(feature.address, operation: feature.writeOperation, bytes: bytes)
        return try await readValue(feature)
    }
}

extension BoseDevice {
    public func currentMode() async throws -> UInt8 {
        try await transaction { device in try await device.readCurrentMode() }
    }

    public func modes() async throws -> [ModeConfiguration] {
        try await transaction { device in try await device.readModes() }
    }

    public func selectMode(_ slot: UInt8, announce: Bool = false) async throws {
        try await transaction { device in
            try device.check(.currentMode, .write)
            try await device.applyMode(slot, announce: announce, from: device.modesConfirming(slot))
        }
    }

    @discardableResult
    public func saveMode(_ draft: ModeDraft) async throws -> ModeConfiguration {
        try await transaction { device in
            let actual = try await device.writeMode(draft)
            device.rememberedCNC[draft.slot] = nil
            return actual
        }
    }

    public func deleteMode(_ slot: UInt8) async throws {
        try await transaction { device in
            guard let policy = device.profile.modePolicy else { throw BoseError.unsupported("Modes") }
            let modes = try await device.readModes()
            guard let current = modes.first(where: { $0.id == slot }), current.editable else {
                throw BoseError.unsupported("Preset mode")
            }
            if device.profile.supports(.currentMode, access: .readWrite),
               try await device.readCurrentMode() == slot {
                guard let fallback = policy.fallbackPreset else {
                    throw BoseError.invalidState("No preset to activate before deleting the current mode")
                }
                try await device.applyMode(fallback, announce: false, from: modes)
            }
            let audio = AudioSettings(cnc: policy.deletionCNC,
                                      ancEnabled: current.audio?.ancEnabled == nil ? nil : false)
            _ = try await device.writeMode(ModeDraft(slot: slot, prompt: 0, name: "None", audio: audio), deleting: true)
            device.rememberedCNC[slot] = nil
        }
    }

    @discardableResult
    public func setFavorite(_ slot: UInt8, _ isFavorite: Bool) async throws -> FavoriteModes {
        try await transaction { device in
            let favorites = try await device.readValue(BoseFeatures.favorites)
            var slots = favorites.slots
            if isFavorite { slots.insert(slot) } else { slots.remove(slot) }
            let actual = try await device.writeValue(BoseFeatures.favorites,
                                                     FavoriteModes(slotCount: favorites.slotCount, slots: slots))
            guard actual.slots.contains(slot) == isFavorite else { throw BoseError.verificationFailed("favorites") }
            return actual
        }
    }

    private func readCurrentMode() async throws -> UInt8 {
        try check(.currentMode, .read)
        let bytes = try await payload(.currentMode)
        try require(bytes, count: 1)
        return bytes[0]
    }

    private func readModes() async throws -> [ModeConfiguration] {
        try check(.modes, .read)
        guard let policy = profile.modePolicy else { throw BoseError.unsupported("Mode codec") }
        let packet = try BMAPPacket(address: .modeList, operation: .start)
        let statusLength = policy.codec.statusLength
        let rule = ResponseRule(
            addresses: [.modeList, .modeIndices, .currentMode, .modeConfiguration, .favorites],
            completion: .quiet(.milliseconds(500)),
            isComplete: { [expected = policy.expectedSlots] packets in
                guard let expected,
                      packets.contains(where: { $0.address == .modeList && $0.operation == .result }) else {
                    return false
                }
                let slots = packets.compactMap { packet -> UInt8? in
                    guard packet.address == .modeConfiguration, packet.operation == .status,
                          packet.payload.count == statusLength else { return nil }
                    return packet.payload[0]
                }
                return expected.isSubset(of: Set(slots))
            }
        )
        let modes = try await session.execute(BMAPCommand(packet: packet, rule: rule, timeout: .seconds(8)) { packets in
            var modes: [UInt8: ModeConfiguration] = [:]
            for packet in packets where packet.address == .modeConfiguration && packet.operation == .status {
                let mode = try policy.codec.decodeStatus(packet.payload)
                modes[mode.id] = mode
            }
            guard !modes.isEmpty else { throw BoseError.invalidPayload("Empty mode list") }
            if let expected = policy.expectedSlots, !expected.isSubset(of: Set(modes.keys)) {
                throw BoseError.invalidPayload("Incomplete mode list")
            }
            return modes.values.sorted { $0.id < $1.id }
        })
        knownModes = modes
        return modes
    }

    private func modesConfirming(_ slot: UInt8) async throws -> [ModeConfiguration] {
        if let knownModes, let policy = profile.modePolicy,
           knownModes.contains(where: { $0.id == slot && policy.isSelectable($0) }) {
            return knownModes
        }
        return try await readModes()
    }

    private func readActiveMode() async throws -> ModeConfiguration {
        let slot = try await readCurrentMode()
        if let mode = knownModes?.first(where: { $0.id == slot }) { return mode }
        guard let mode = try await readModes().first(where: { $0.id == slot }) else {
            throw BoseError.invalidState("Current mode unavailable")
        }
        return mode
    }

    private func applyMode(_ slot: UInt8, announce: Bool, from available: [ModeConfiguration]) async throws {
        guard let policy = profile.modePolicy,
              available.contains(where: { $0.id == slot && policy.isSelectable($0) }) else {
            throw BoseError.invalidState("Mode is not configured")
        }
        _ = try await payload(.currentMode, operation: .start, bytes: [slot, announce ? 1 : 0])
        guard try await readCurrentMode() == slot else { throw BoseError.verificationFailed("currentMode") }
    }

    private func writeMode(_ draft: ModeDraft, deleting: Bool = false) async throws -> ModeConfiguration {
        try check(.modes, .write)
        guard let policy = profile.modePolicy, policy.editableSlots.contains(draft.slot) else {
            throw BoseError.unsupported("Preset or unknown mode slot")
        }
        guard policy.allowsCustomAutoCNC || !draft.audio.automaticCNC else {
            throw BoseError.unsupported("Automatic CNC in custom modes")
        }
        if draft.audio.spatial != .off { try check(.spatialAudio, .write) }
        if draft.audio.windBlock { try check(.windBlock, .write) }
        let bytes = try policy.codec.encodeWrite(draft)
        _ = try await payload(.modeConfiguration, operation: .setGet, bytes: bytes)
        guard let actual = try await readModes().first(where: { $0.id == draft.slot }) else {
            throw BoseError.verificationFailed("Missing mode after write")
        }
        var expected = draft.audio
        if policy.windForcesMaximumANC && expected.windBlock { expected.cnc = 0 }
        guard actual.name == draft.name, actual.prompt == draft.prompt, actual.audio == expected else {
            throw BoseError.verificationFailed("Mode fields differ after write")
        }
        if deleting && policy.deletionClearsConfigured && actual.configured {
            throw BoseError.verificationFailed("Deleted slot remains configured")
        }
        if !deleting && !actual.configured { throw BoseError.verificationFailed("Mode is not configured") }
        return actual
    }
}

extension BoseDevice {
    @discardableResult
    public func setCNC(_ level: UInt8) async throws -> AudioSettings? {
        guard level <= 10 else { throw BoseError.invalidArgument("CNC must be 0...10") }
        return try await transaction { device in
            switch device.profile.noiseControl {
            case .directCNC:
                guard try await device.writeValue(BoseFeatures.cnc, level).current == level else {
                    throw BoseError.verificationFailed("CNC")
                }
                return nil
            case .audioSettings, .modeConfiguration:
                return try await device.modifyAudio { audio, modeSlot in
                    if modeSlot != nil && audio.windBlock {
                        throw BoseError.invalidState("Disable wind block before changing CNC")
                    }
                    audio.cnc = level
                }
            case .unavailable, .anr:
                throw BoseError.unsupported("Continuous noise control")
            }
        }
    }

    @discardableResult
    public func setWindBlock(_ enabled: Bool) async throws -> AudioSettings {
        try await transaction { device in
            try device.check(.windBlock, .write)
            var remember: (slot: UInt8, cnc: UInt8)?
            var restoredSlot: UInt8?
            let actual = try await device.modifyAudio { audio, modeSlot in
                if let modeSlot {
                    if enabled && !audio.windBlock { remember = (modeSlot, audio.cnc) }
                    if !enabled {
                        restoredSlot = modeSlot
                        if let cnc = device.rememberedCNC[modeSlot] { audio.cnc = cnc }
                    }
                }
                audio.windBlock = enabled
            }
            if let remember { device.rememberedCNC[remember.slot] = remember.cnc }
            if let restoredSlot { device.rememberedCNC[restoredSlot] = nil }
            return actual
        }
    }

    @discardableResult
    public func setSpatialAudio(_ spatial: SpatialAudio) async throws -> AudioSettings {
        try await transaction { device in
            try device.check(.spatialAudio, .write)
            return try await device.modifyAudio { audio, _ in audio.spatial = spatial }
        }
    }

    @discardableResult
    public func setANCEnabled(_ enabled: Bool) async throws -> AudioSettings {
        try await transaction { device in
            try device.check(.ancToggle, .write)
            return try await device.modifyAudio { audio, _ in audio.ancEnabled = enabled }
        }
    }

    @discardableResult
    public func setAutomaticCNC(_ enabled: Bool) async throws -> AudioSettings {
        try await transaction { device in
            try device.check(.audioSettings, .write)
            return try await device.modifyAudio { audio, _ in audio.automaticCNC = enabled }
        }
    }

    private func modifyAudio(
        _ change: (inout AudioSettings, _ modeSlot: UInt8?) throws -> Void
    ) async throws -> AudioSettings {
        switch profile.noiseControl {
        case .audioSettings:
            var audio = try await readValue(BoseFeatures.audioSettings)
            try change(&audio, nil)
            let actual = try await writeValue(BoseFeatures.audioSettings, audio)
            guard actual == audio else { throw BoseError.verificationFailed("Audio settings") }
            return actual
        case .modeConfiguration:
            let mode = try await readActiveMode()
            guard var audio = mode.audio else { throw BoseError.invalidState("Current mode has no audio settings") }
            try change(&audio, mode.id)
            let actual = try await writeMode(ModeDraft(slot: mode.id, prompt: mode.prompt, name: mode.name, audio: audio))
            guard let actualAudio = actual.audio else { throw BoseError.verificationFailed("Audio settings") }
            return actualAudio
        case .unavailable, .anr, .directCNC:
            throw BoseError.unsupported("Audio settings")
        }
    }
}

extension BoseDevice {
    @discardableResult
    public func setVoicePromptsEnabled(_ enabled: Bool) async throws -> VoicePrompts {
        try await updateVoicePrompts { $0.enabled = enabled }
    }

    @discardableResult
    public func setVoicePromptLanguage(_ language: VoicePromptLanguage) async throws -> VoicePrompts {
        try await updateVoicePrompts { $0.language = language }
    }

    @discardableResult
    public func resetEqualizer() async throws -> [EQBand] {
        try await transaction { device in
            var bands = try await device.readValue(BoseFeatures.equalizer)
            for band in bands where band.value != 0 {
                bands = try await device.writeValue(BoseFeatures.equalizer, EQAdjustment(band: band.id, value: 0))
            }
            guard bands.allSatisfy({ $0.value == 0 }) else { throw BoseError.verificationFailed("equalizer") }
            return bands
        }
    }

    public func sourceDevices() async throws -> [SourceDevice] {
        try await transaction { device in
            try device.check(.sourceDevices, .read)
            let addresses = try SourceDeviceCodec.decodeList(await device.payload(.deviceList))
            let activeSource = device.profile.supports(.source)
                ? try await device.readValue(BoseFeatures.source).bluetoothAddress
                : nil
            var devices: [SourceDevice] = []
            for address in addresses {
                let info = try await device.payload(.deviceInfo, bytes: address.bytes)
                devices.append(try SourceDeviceCodec.decodeInfo(info, for: address, activeSource: activeSource))
            }
            return devices
        }
    }

    public func routeAudio(to address: BluetoothAddress) async throws {
        try await transaction { device in
            try device.check(.routing, .write)
            _ = try await device.payload(.routing, operation: .start, bytes: [0x82] + address.bytes)
        }
    }

    public func powerOff() async throws {
        try await transaction { device in
            try device.check(.power, .write)
            _ = try await device.payload(.power, operation: .start, bytes: [0])
        }
    }

    private func updateVoicePrompts(_ change: @Sendable (inout VoicePrompts) -> Void) async throws -> VoicePrompts {
        try await transaction { device in
            var prompts = try await device.readValue(BoseFeatures.voicePrompts)
            change(&prompts)
            let actual = try await device.writeValue(BoseFeatures.voicePrompts, prompts)
            guard actual.enabled == prompts.enabled, actual.language == prompts.language else {
                throw BoseError.verificationFailed("voicePrompts")
            }
            return actual
        }
    }
}
