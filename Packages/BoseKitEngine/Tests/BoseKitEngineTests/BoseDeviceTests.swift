import Testing
@testable import BoseKitEngine

@Suite(.timeLimit(.minutes(1)))
struct BoseDeviceTests {
    @Test func writeToReadOnlyFeatureNeverReachesTransport() async throws {
        let goodyear = DeviceProfile.goodyear
        let transport = ScriptedTransport(responder: { bytes in [[bytes[0], bytes[1], 3, 0]] })
        let device = try await connectedDevice(on: transport, profile: goodyear)
        await #expect(throws: BoseError.unsupported(.feature(.equalizer))) {
            try await device.write(BoseFeatures.equalizer, value: EQAdjustment(band: 0, value: 1))
        }
        #expect(await transport.writes == goodyear.initialization.map(\.bytes))
        await device.close()
    }

    @Test func readOfFeatureMissingFromProfileNeverReachesTransport() async throws {
        let transport = ScriptedTransport()
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.unsupported(.feature(.anr))) {
            try await device.read(BoseFeatures.anr)
        }
        #expect(await transport.writes.isEmpty)
        await device.close()
    }

    @Test func writeReturnsTheIndependentReadBack() async throws {
        let transport = ScriptedTransport(script: [
            [frame(.multipoint, .status, [0])],
            [frame(.multipoint, .status, [7])],
        ])
        let device = try await connectedDevice(on: transport)
        #expect(try await device.write(BoseFeatures.multipoint, value: true))
        #expect(await transport.writes == [
            frame(.multipoint, .setGet, [1]),
            frame(.multipoint, .get),
        ])
        await device.close()
    }

    @Test func writeFailsVerificationWhenReadBackDisagrees() async throws {
        let transport = ScriptedTransport(responder: { bytes in
            bytes[2] == 2 ? [[1, 10, 3, 1, 1]] : [[1, 10, 3, 1, 6]]
        })
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.verificationFailed(.feature(.multipoint))) {
            try await device.write(BoseFeatures.multipoint, value: true)
        }
        #expect(await transport.writes.map { $0[2] } == [2, 1])
        await device.close()
    }

    @Test func remoteErrorOnWriteSkipsReadBack() async throws {
        let transport = ScriptedTransport(script: [[frame(.multipoint, .error, [5])]])
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.device(.multipoint, code: .operatorNotSupported, detail: nil)) {
            try await device.write(BoseFeatures.multipoint, value: true)
        }
        #expect(await transport.writes.count == 1)
        await device.close()
    }
}
