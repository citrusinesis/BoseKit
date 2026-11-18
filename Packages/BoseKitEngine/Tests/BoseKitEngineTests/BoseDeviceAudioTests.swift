import Testing
@testable import BoseKitEngine

@Suite(.timeLimit(.minutes(1)))
struct BoseDeviceAudioTests {
    @Test func repeatedAudioChangesReuseKnownModeList() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        let first = try await device.setCNC(5)
        let second = try await device.setCNC(4)
        #expect(first?.cnc == 5)
        #expect(second?.cnc == 4)
        let enumerations = await transport.writes.filter { $0[0] == 31 && $0[1] == 1 }
        #expect(enumerations.count == 3)
        await device.close()
    }

    @Test func firmwareNormalizationAndWindRestoration() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        try await device.setWindBlock(true)
        try await device.setWindBlock(false)
        let writes = await transport.writes.filter { $0[1] == 6 }
        #expect(writes.count == 2)
        #expect(writes[0][4 + 38] == 1)
        #expect(writes[1][4 + 35] == 7)
        #expect(writes[1][4 + 38] == 0)
        await device.close()
    }

    @Test func setCNCIsRejectedWhileWindBlockIsOn() async throws {
        let transport = ModeSimulatorTransport()
        let device = try await connectedDevice(on: transport)
        try await device.setWindBlock(true)
        let writesBefore = await transport.writes.count
        await #expect(throws: BoseError.invalidState(.windBlockLocksCNC)) {
            try await device.setCNC(4)
        }
        let modeWrites = await transport.writes.dropFirst(writesBefore).filter { $0[1] == 6 }
        #expect(modeWrites.isEmpty)
        await device.close()
    }

    @Test func activeModeWhoseNameCannotBeWrittenBackIsRejectedBeforeWriting() async throws {
        let transport = ModeSimulatorTransport(currentModeName: Array(repeating: 0x71, count: 32))
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.invalidState(.modeNameNotWritable)) {
            try await device.setCNC(4)
        }
        #expect(await transport.writes.filter { $0[1] == 6 }.isEmpty)
        await device.close()
    }

    @Test func setCNCOnProfileWithoutNoiseControlIsUnsupported() async throws {
        let transport = ScriptedTransport()
        let device = try await connectedDevice(on: transport, profile: .serena)
        await #expect(throws: BoseError.unsupported(.continuousNoiseControl)) {
            try await device.setCNC(3)
        }
        #expect(await transport.writes.isEmpty)
        await device.close()
    }
}
