import Testing
@testable import BoseKitEngine

@Suite(.timeLimit(.minutes(1)))
struct DeviceRequestBytesTests {
    private static let wolverine: UInt16 = 0x4082
    private static let lando: UInt16 = 0x402f

    private static func modeWrite(_ slot: UInt8, prompt: [UInt8], name: String, audio: [UInt8]) -> [UInt8] {
        [31, 6, 2, 39, slot] + prompt + padded(Array(name.utf8), to: 32) + audio
    }

    @Test func legacyProfileInitializationIsProductInfoGet() async throws {
        let transport = ScriptedTransport(responder: { bytes in [[bytes[0], bytes[1], 3, 0]] })
        let device = try await connectedDevice(on: transport, profile: wireProfile(0x400c))
        #expect(await transport.writes == [[0, 1, 1, 0]])
        await device.close()
    }

    @Test func goodyearInitializationEnablesNotifications() async throws {
        let transport = ScriptedTransport(responder: { bytes in [[bytes[0], bytes[1], 3, 0]] })
        let device = try await connectedDevice(on: transport, profile: wireProfile(0x4024))
        #expect(await transport.writes == [[9, 2, 2, 5, 1, 0, 5, 2, 0x37]])
        await device.close()
    }

    @Test func selectModeWritesListStartThenModeStartThenCurrentModeRead() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        try await device.selectMode(0)
        #expect(await transport.writes == [[31, 1, 5, 0], [31, 3, 5, 2, 0, 0], [31, 3, 1, 0]])
        await device.close()
    }

    @Test func selectModeWithAnnouncementSetsTheSecondPayloadByteAndReusesTheKnownList() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        try await device.selectMode(0)
        try await device.selectMode(1, announce: true)
        #expect(Array(await transport.writes.dropFirst(3)) == [[31, 3, 5, 2, 1, 1], [31, 3, 1, 0]])
        await device.close()
    }

    @Test func modeListEnumerationIsAStartWithNoPayloadAndDecodesTenSortedSlots() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        let modes = try await device.modes()
        #expect(await transport.writes == [[31, 1, 5, 0]])
        #expect(modes.map(\.id) == Array(0...9))
        await device.close()
    }

    @Test func routeAudioStartsRoutingWithTheSelectorByteAndTheAddress() async throws {
        let transport = ScriptedTransport(responder: { bytes in [[bytes[0], bytes[1], 6, 0]] })
        let device = try await connectedDevice(on: transport, profile: wireProfile(Self.wolverine))
        try await device.routeAudio(to: address("BC:D0:74:72:78:52"))
        #expect(await transport.writes == [[4, 12, 5, 7, 0x82, 0xbc, 0xd0, 0x74, 0x72, 0x78, 0x52]])
        await device.close()
    }

    @Test func powerOffStartsPowerWithASingleZeroByte() async throws {
        let transport = ScriptedTransport(responder: { bytes in [[bytes[0], bytes[1], 6, 0]] })
        let device = try await connectedDevice(on: transport)
        try await device.powerOff()
        #expect(await transport.writes == [[7, 4, 5, 1, 0]])
        await device.close()
    }

    @Test func pairingWriteUsesStartThenReadsBackWithGet() async throws {
        let transport = ScriptedTransport(script: [
            [frame(.pairing, .result)],
            [frame(.pairing, .status, [1])],
        ])
        let device = try await connectedDevice(on: transport)
        #expect(try await device.write(BoseFeatures.pairing, value: true))
        #expect(await transport.writes == [[4, 8, 5, 1, 1], [4, 8, 1, 0]])
        await device.close()
    }

    @Test func nameWriteSendsTheRawUTF8ThenReadsBack() async throws {
        let name = Array("Citrus QC".utf8)
        let transport = ScriptedTransport(script: [
            [frame(.name, .status, [0] + name)],
            [frame(.name, .status, [0] + name)],
        ])
        let device = try await connectedDevice(on: transport)
        #expect(try await device.write(BoseFeatures.name, value: "Citrus QC") == "Citrus QC")
        #expect(await transport.writes == [[1, 2, 2, 9] + name, [1, 2, 1, 0]])
        await device.close()
    }

    @Test(arguments: ["", String(repeating: "z", count: 32), "bad\0name"])
    func invalidNameCannotBeConstructedForTheTransport(_ name: String) {
        #expect(DeviceName(rawValue: name) == nil)
    }

    @Test func negativeEqualizerAdjustmentWritesTwosComplementValueThenBand() async throws {
        let transport = ScriptedTransport(responder: { _ in [[1, 7, 3, 4, 246, 10, 249, 1]] })
        let device = try await connectedDevice(on: transport)
        let bands = try await device.setEqualizer(band: 1, value: -7)
        #expect(bands == [EQBand(id: 1, range: -10...10, value: -7)])
        #expect(await transport.writes == [[1, 7, 1, 0], [1, 7, 2, 2, 249, 1], [1, 7, 1, 0]])
        await device.close()
    }

    @Test func directCNCWriteSendsLevelAndFlagThenReadsBack() async throws {
        let transport = ScriptedTransport(responder: { _ in [[1, 5, 3, 3, 11, 6, 1]] })
        let device = try await connectedDevice(on: transport, profile: wireProfile(Self.lando))
        #expect(try await device.setCNC(6) == nil)
        #expect(await transport.writes == [[1, 5, 2, 2, 6, 1], [1, 5, 1, 0]])
        await device.close()
    }

    @Test func saveModeWritesTheThirtyNineBytePayloadThenEnumeratesTheList() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        _ = try await device.saveMode(ModeDraft(slot: 4, prompt: .work, name: "Work",
                                                audio: AudioSettings(cnc: 6, spatial: .still)))
        #expect(await transport.writes == [
            Self.modeWrite(4, prompt: [0, 11], name: "Work", audio: [6, 0, 1, 0]),
            [31, 1, 5, 0],
        ])
        await device.close()
    }

    @Test func deleteModeReadsListAndCurrentModeThenWritesTheVerifiedResetPayload() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        try await device.deleteMode(4)
        #expect(await transport.writes == [
            [31, 1, 5, 0],
            [31, 3, 1, 0],
            Self.modeWrite(4, prompt: [0, 0], name: "None", audio: [10, 0, 0, 0]),
            [31, 1, 5, 0],
        ])
        await device.close()
    }

    @Test func deletingTheActiveModeSelectsPresetZeroSilentlyBeforeTheResetWrite() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        try await device.deleteMode(3)
        #expect(await transport.writes == [
            [31, 1, 5, 0],
            [31, 3, 1, 0],
            [31, 3, 5, 2, 0, 0],
            [31, 3, 1, 0],
            Self.modeWrite(3, prompt: [0, 0], name: "None", audio: [10, 0, 0, 0]),
            [31, 1, 5, 0],
        ])
        await device.close()
    }

    @Test func enablingWindBlockKeepsTheCurrentCNCInTheWritePayload() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        try await device.setWindBlock(true)
        #expect(await transport.writes == [
            [31, 3, 1, 0],
            [31, 1, 5, 0],
            Self.modeWrite(3, prompt: [0, 0], name: "X", audio: [7, 0, 0, 1]),
            [31, 1, 5, 0],
        ])
        await device.close()
    }
}
