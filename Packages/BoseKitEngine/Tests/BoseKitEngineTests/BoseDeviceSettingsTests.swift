import Testing
@testable import BoseKitEngine

@Suite(.timeLimit(.minutes(1)))
struct BoseDeviceSettingsTests {
    private static func bands(_ values: [Int8]) -> [UInt8] {
        values.enumerated().flatMap { index, value in
            [UInt8(bitPattern: -10), 10, UInt8(bitPattern: value), UInt8(index)]
        }
    }

    private static func equalizerFrame(_ values: [Int8]) -> [UInt8] {
        frame(.equalizer, .status, bands(values))
    }

    private static func adjustment(band: UInt8, value: Int8 = 0) -> [UInt8] {
        frame(.equalizer, .setGet, [UInt8(bitPattern: value), band])
    }

    @Test func equalizerWritesAreValidatedAgainstDeviceBands() async throws {
        let bands: [UInt8] = [246, 10, 0, 0, 251, 5, 4, 3]
        let transport = ScriptedTransport(responder: { _ in
            [[1, 7, 3, UInt8(bands.count)] + bands]
        })
        let device = try await connectedDevice(on: transport)
        let result = try await device.setEqualizer(band: 3, value: 4)
        #expect(result.first { $0.id == 3 }?.value == 4)
        #expect(await transport.writes[1] == [1, 7, 2, 2, 4, 3])
        await #expect(throws: BoseError.self) { try await device.setEqualizer(band: 3, value: 6) }
        await #expect(throws: BoseError.self) { try await device.setEqualizer(band: 7, value: 0) }
        #expect(await transport.writes.count == 5)
        await device.close()
    }

    @Test func setEqualizerFailsVerificationWhenReadBackDiffers() async throws {
        let bands: [UInt8] = [246, 10, 0, 0]
        let transport = ScriptedTransport(responder: { _ in [[1, 7, 3, UInt8(bands.count)] + bands] })
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.verificationFailed(.feature(.equalizer))) {
            try await device.setEqualizer(band: 0, value: 2)
        }
        await device.close()
    }

    @Test func resetEqualizerWritesOnlyNonZeroBands() async throws {
        let transport = ScriptedTransport(script: [
            [Self.equalizerFrame([0, 3, -2, 0])],
            [Self.equalizerFrame([0, 0, -2, 0])],
            [Self.equalizerFrame([0, 0, -2, 0])],
            [Self.equalizerFrame([0, 0, 0, 0])],
            [Self.equalizerFrame([0, 0, 0, 0])],
        ])
        let device = try await connectedDevice(on: transport)
        let result = try await device.resetEqualizer()
        #expect(result.allSatisfy { $0.value == 0 })
        #expect(await transport.writes == [
            frame(.equalizer, .get),
            Self.adjustment(band: 1),
            frame(.equalizer, .get),
            Self.adjustment(band: 2),
            frame(.equalizer, .get),
        ])
        await device.close()
    }

    @Test func resetEqualizerOnFlatBandsOnlyReads() async throws {
        let transport = ScriptedTransport(script: [[Self.equalizerFrame([0, 0, 0, 0])]])
        let device = try await connectedDevice(on: transport)
        let result = try await device.resetEqualizer()
        #expect(result.count == 4)
        #expect(await transport.writes == [frame(.equalizer, .get)])
        await device.close()
    }

    @Test func resetEqualizerFailsWhenBandStaysNonZero() async throws {
        let transport = ScriptedTransport(script: [
            [Self.equalizerFrame([2, 0])],
            [Self.equalizerFrame([2, 0])],
            [Self.equalizerFrame([2, 0])],
        ])
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.verificationFailed(.feature(.equalizer))) {
            try await device.resetEqualizer()
        }
        await device.close()
    }

    @Test func resetEqualizerFailsWhenAnotherBandDriftsNonZero() async throws {
        let transport = ScriptedTransport(script: [
            [Self.equalizerFrame([2, 0])],
            [Self.equalizerFrame([0, 5])],
            [Self.equalizerFrame([0, 5])],
        ])
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.verificationFailed(.feature(.equalizer))) {
            try await device.resetEqualizer()
        }
        await device.close()
    }

    @Test func disablingVoicePromptsKeepsHighBitsAndLanguage() async throws {
        let transport = ScriptedTransport(script: [
            [frame(.voicePrompts, .status, [0xa1])],
            [frame(.voicePrompts, .status, [0x81])],
            [frame(.voicePrompts, .status, [0x81])],
        ])
        let device = try await connectedDevice(on: transport)
        let result = try await device.setVoicePromptsEnabled(false)
        #expect(result == VoicePrompts(enabled: false, language: .englishUS, preservedBits: 0x80))
        #expect(await transport.writes == [
            frame(.voicePrompts, .get),
            frame(.voicePrompts, .setGet, [0x81]),
            frame(.voicePrompts, .get),
        ])
        await device.close()
    }

    @Test func changingVoicePromptLanguageKeepsHighBitsAndEnabledFlag() async throws {
        let transport = ScriptedTransport(script: [
            [frame(.voicePrompts, .status, [0xa1])],
            [frame(.voicePrompts, .status, [0xa9])],
            [frame(.voicePrompts, .status, [0xa9])],
        ])
        let device = try await connectedDevice(on: transport)
        let result = try await device.setVoicePromptLanguage(.korean)
        #expect(result == VoicePrompts(enabled: true, language: .korean, preservedBits: 0x80))
        #expect(await transport.writes[1] == frame(.voicePrompts, .setGet, [0xa9]))
        await device.close()
    }

    @Test func voicePromptUpdateFailsVerificationWhenReadBackDiffers() async throws {
        let transport = ScriptedTransport(script: [
            [frame(.voicePrompts, .status, [0xa1])],
            [frame(.voicePrompts, .status, [0xa1])],
            [frame(.voicePrompts, .status, [0xa1])],
        ])
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.verificationFailed(.feature(.voicePrompts))) {
            try await device.setVoicePromptsEnabled(false)
        }
        await device.close()
    }

    @Test func sourceDevicesUseCapturedLonestarrReplies() async throws {
        let list: [UInt8] = [0x03, 0x64, 0x31, 0x35, 0x81, 0x98, 0x67, 0xbc, 0xd0, 0x74, 0x72, 0x78, 0x52,
                             0x1c, 0xf6, 0x4c, 0x52, 0x34, 0xcb]
        let info: [[UInt8]: [UInt8]] = [
            [0x64, 0x31, 0x35, 0x81, 0x98, 0x67]: [0x01, 0x02, 0x03] + Array("lemon".utf8),
            [0xbc, 0xd0, 0x74, 0x72, 0x78, 0x52]: [0x03, 0x02, 0x03] + Array("juicer".utf8),
            [0x1c, 0xf6, 0x4c, 0x52, 0x34, 0xcb]: [0x00, 0x02, 0x03] + Array("mixer".utf8),
        ]
        let transport = ScriptedTransport(responder: { bytes in
            switch (bytes[0], bytes[1]) {
            case (4, 4): return [[4, 4, 3, UInt8(list.count)] + list]
            case (5, 1): return [[5, 1, 3, 9, 0x00, 0x0f, 0x01, 0x64, 0x31, 0x35, 0x81, 0x98, 0x67]]
            case (4, 5):
                let address = Array(bytes[4..<10])
                let payload = address + (info[address] ?? [])
                return [[4, 5, 3, UInt8(payload.count)] + payload]
            default: return [[bytes[0], bytes[1], 4, 1, 5]]
            }
        })
        let device = try await connectedDevice(on: transport)
        let devices = try await device.sourceDevices()
        #expect(devices.map(\.name) == ["lemon", "juicer", "mixer"])
        #expect(devices.map(\.isConnected) == [true, true, false])
        #expect(devices.map(\.isRequestingHost) == [false, true, false])
        #expect(devices.map(\.isActiveSource) == [true, false, false])
        #expect(devices[1].address.description == "BC:D0:74:72:78:52")
        await device.close()
    }
}
