import Testing
@testable import BoseKitEngine

private func profileWithoutFallbackPreset() -> DeviceProfile {
    DeviceProfile(
        id: "no-fallback", name: "No fallback", productIDs: [0xfff1], rfcommChannel: 2,
        features: [.modes: .readWrite, .currentMode: .readWrite],
        noiseControl: .modeConfiguration,
        modePolicy: ModePolicy(codec: StandardModeCodec(.status47), editableSlots: [3],
                               expectedSlots: Set(0...9))
    )
}

@Suite(.timeLimit(.minutes(1)))
struct ModeTransactionTests {
    @Test func presetsWithConfiguredZeroRemainSelectable() async throws {
        let device = try await connectedDevice(on: ModeSimulatorTransport())
        for slot: UInt8 in [0, 1, 2] {
            try await device.selectMode(slot)
            #expect(try await device.currentMode() == slot)
        }
        await #expect(throws: BoseError.invalidState(.modeNotConfigured)) {
            try await device.selectMode(4)
        }
        await device.close()
    }

    @Test func repeatedSelectionReusesKnownModeList() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        try await device.selectMode(0)
        try await device.selectMode(3)
        try await device.selectMode(1)
        let enumerations = await transport.writes.filter { $0[0] == 31 && $0[1] == 1 }
        #expect(enumerations.count == 1)
        #expect(try await device.currentMode() == 1)
        await device.close()
    }

    @Test func savesThenReadsAndDeletesWithVerifiedLonestarrReset() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        let result = try await device.saveMode(ModeDraft(slot: 4, prompt: .work, name: "Work",
                                                        audio: AudioSettings(cnc: 6)))
        #expect(result.configured)
        #expect(result.audio?.cnc == 6)
        try await device.deleteMode(4)
        let writes = await transport.writes.filter { $0[1] == 6 }
        let deletion = try #require(writes.last)
        #expect(deletion[4 + 35] == 10)
        #expect(Array(deletion[(4 + 36)...]) == [0, 0, 0])
        await device.close()
    }

    @Test func deletingActiveModeSwitchesToFallbackPresetFirst() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        #expect(try await device.currentMode() == 3)
        try await device.deleteMode(3)
        #expect(try await device.currentMode() == 0)
        let commands = await transport.writes.map { [$0[1], $0[2]] }
        let selection = try #require(commands.firstIndex(of: [3, 5]))
        let deletion = try #require(commands.firstIndex(of: [6, 2]))
        #expect(selection < deletion)
        await device.close()
    }

    @Test func deletingActiveModeWithoutFallbackPresetFailsBeforeAnyWrite() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport, profile: profileWithoutFallbackPreset())
        await #expect(throws: BoseError.invalidState(.noFallbackPreset)) {
            try await device.deleteMode(3)
        }
        let mutations = await transport.writes.filter { $0[1] == 6 || ($0[1] == 3 && $0[2] == 5) }
        #expect(mutations.isEmpty)
        await device.close()
    }

    @Test func deletingPresetSlotIsRejected() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.unsupported(.nonEditableModeSlot(1))) {
            try await device.deleteMode(1)
        }
        #expect(await transport.writes.filter { $0[1] == 6 }.isEmpty)
        await device.close()
    }

    @Test func presetAndAutoCNCRejectionHappenBeforeIO() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.self) {
            try await device.saveMode(ModeDraft(slot: 0, prompt: .quiet, name: "Quiet", audio: AudioSettings(cnc: 0)))
        }
        await #expect(throws: BoseError.self) {
            try await device.saveMode(ModeDraft(slot: 4, prompt: .work, name: "Work",
                                                audio: AudioSettings(cnc: 0, automaticCNC: true)))
        }
        #expect(await transport.writes.isEmpty)
        await device.close()
    }

    @Test func acceptedWriteWithWrongFieldFailsVerification() async throws {
        let device = try await connectedDevice(on: ModeSimulatorTransport(corruptReadBack: true))
        await #expect(throws: BoseError.verificationFailed(.modeFieldsDiffer)) {
            try await device.saveMode(ModeDraft(slot: 4, prompt: .work, name: "Work", audio: AudioSettings(cnc: 6)))
        }
        await device.close()
    }

    @Test func simultaneousModeWritesKeepReadBackInsideTransaction() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        async let a = device.saveMode(ModeDraft(slot: 4, prompt: .work, name: "Work", audio: AudioSettings(cnc: 3)))
        async let b = device.saveMode(ModeDraft(slot: 5, prompt: .music, name: "Music", audio: AudioSettings(cnc: 5)))
        _ = try await (a, b)
        #expect(await transport.writes.map { $0[1] } == [6, 1, 6, 1])
        await device.close()
    }
}
