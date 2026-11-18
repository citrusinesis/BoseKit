extension BoseDevice {
    private static let routeToAddressSelector: UInt8 = 0x82
    private static let powerOffRequest: UInt8 = 0

    @discardableResult
    public func setVoicePromptsEnabled(_ enabled: Bool) async throws -> VoicePrompts {
        try await updateVoicePrompts { $0.enabled = enabled }
    }

    @discardableResult
    public func setVoicePromptLanguage(_ language: VoicePromptLanguage) async throws -> VoicePrompts {
        try await updateVoicePrompts { $0.language = language }
    }

    @discardableResult
    public func setEqualizer(band: UInt8, value: Int8) async throws -> [EQBand] {
        try await transaction { device in
            let bands = try await device.readValue(BoseFeatures.equalizer)
            guard let target = bands.first(where: { $0.id == band }) else {
                throw BoseError.invalidArgument("Unknown EQ band \(band)")
            }
            return try await device.writeValue(BoseFeatures.equalizer, try target.adjustment(to: value))
        }
    }

    @discardableResult
    public func resetEqualizer() async throws -> [EQBand] {
        try await transaction { device in
            var bands = try await device.readValue(BoseFeatures.equalizer)
            for band in bands where band.value != 0 {
                bands = try await device.writeValue(BoseFeatures.equalizer, try band.adjustment(to: 0))
            }
            guard bands.allSatisfy({ $0.value == 0 }) else { throw BoseError.verificationFailed(.feature(.equalizer)) }
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
            _ = try await device.payload(.routing, operation: .start, bytes: PayloadWriter.build { writer in
                writer.u8(Self.routeToAddressSelector)
                writer.append(address.bytes)
            })
        }
    }

    public func powerOff() async throws {
        try await transaction { device in
            try device.check(.power, .write)
            _ = try await device.payload(.power, operation: .start, bytes: [Self.powerOffRequest])
        }
    }

    private func updateVoicePrompts(_ change: @Sendable (inout VoicePrompts) -> Void) async throws -> VoicePrompts {
        try await transaction { device in
            var prompts = try await device.readValue(BoseFeatures.voicePrompts)
            change(&prompts)
            return try await device.writeValue(BoseFeatures.voicePrompts, prompts)
        }
    }
}
