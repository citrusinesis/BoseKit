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
            guard let policy = device.profile.modePolicy else { throw BoseError.unsupported(.modePolicy) }
            let modes = try await device.readModes()
            guard let current = modes.first(where: { $0.id == slot }), current.editable else {
                throw BoseError.unsupported(.nonEditableModeSlot(slot))
            }
            if device.profile.supports(.currentMode, access: .readWrite),
               try await device.readCurrentMode() == slot {
                guard let fallback = policy.fallbackPreset else { throw BoseError.invalidState(.noFallbackPreset) }
                try await device.applyMode(fallback, announce: false, from: modes)
            }
            let audio = AudioSettings(cnc: policy.deletionCNC,
                                      ancEnabled: current.audio?.ancEnabled == nil ? nil : false)
            let draft = ModeDraft(slot: slot, prompt: .none, name: ModeConfiguration.emptyName, audio: audio)
            _ = try await device.writeMode(draft, deleting: true)
            device.rememberedCNC[slot] = nil
        }
    }

    @discardableResult
    public func setFavorite(_ slot: UInt8, _ isFavorite: Bool) async throws -> FavoriteModes {
        try await transaction { device in
            let favorites = try await device.readValue(BoseFeatures.favorites)
            var slots = favorites.slots
            if isFavorite { slots.insert(slot) } else { slots.remove(slot) }
            return try await device.writeValue(BoseFeatures.favorites,
                                               try FavoriteModes(slotCount: favorites.slotCount, slots: slots))
        }
    }

    func readCurrentMode() async throws -> UInt8 {
        try check(.currentMode, .read)
        let bytes = try await payload(.currentMode)
        return try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { try $0.u8() }
    }

    func readModes() async throws -> [ModeConfiguration] {
        try check(.modes, .read)
        guard let policy = profile.modePolicy else { throw BoseError.unsupported(.modePolicy) }
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

    func readActiveMode() async throws -> ModeConfiguration {
        let slot = try await readCurrentMode()
        if let mode = knownModes?.first(where: { $0.id == slot }) { return mode }
        guard let mode = try await readModes().first(where: { $0.id == slot }) else {
            throw BoseError.invalidState(.currentModeUnavailable)
        }
        return mode
    }

    private func applyMode(_ slot: UInt8, announce: Bool, from available: [ModeConfiguration]) async throws {
        guard let policy = profile.modePolicy,
              available.contains(where: { $0.id == slot && policy.isSelectable($0) }) else {
            throw BoseError.invalidState(.modeNotConfigured)
        }
        let selection = PayloadWriter.build { writer in
            writer.u8(slot)
            writer.bool(announce)
        }
        _ = try await payload(.currentMode, operation: .start, bytes: selection)
        guard try await readCurrentMode() == slot else { throw BoseError.verificationFailed(.currentModeNotApplied) }
    }

    func writeMode(_ draft: ModeDraft, deleting: Bool = false) async throws -> ModeConfiguration {
        try check(.modes, .write)
        guard let policy = profile.modePolicy else { throw BoseError.unsupported(.modePolicy) }
        guard policy.editableSlots.contains(draft.slot) else {
            throw BoseError.unsupported(.nonEditableModeSlot(draft.slot))
        }
        guard policy.allowsCustomAutoCNC || !draft.audio.automaticCNC else {
            throw BoseError.unsupported(.automaticCNCInCustomModes)
        }
        if draft.audio.spatial != .off { try check(.spatialAudio, .write) }
        if draft.audio.windBlock { try check(.windBlock, .write) }
        let bytes = try policy.codec.encodeWrite(draft)
        _ = try await payload(.modeConfiguration, operation: .setGet, bytes: bytes)
        guard let actual = try await readModes().first(where: { $0.id == draft.slot }) else {
            throw BoseError.verificationFailed(.modeMissingAfterWrite)
        }
        var expected = draft.audio
        if policy.windForcesMaximumANC && expected.windBlock { expected.cnc = 0 }
        guard actual.name == draft.name.rawValue, actual.prompt == draft.prompt, actual.audio == expected else {
            throw BoseError.verificationFailed(.modeFieldsDiffer)
        }
        if deleting && policy.deletionClearsConfigured && actual.configured {
            throw BoseError.verificationFailed(.deletedModeStillConfigured)
        }
        if !deleting && !actual.configured { throw BoseError.verificationFailed(.modeNotConfigured) }
        return actual
    }
}
