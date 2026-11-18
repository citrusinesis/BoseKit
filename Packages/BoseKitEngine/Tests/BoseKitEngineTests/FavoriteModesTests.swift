import Testing
@testable import BoseKitEngine

@Suite(.timeLimit(.minutes(1)))
struct FavoriteModesTests {
    private static func favorites(_ mask: UInt8) -> [UInt8] {
        frame(.favorites, .status, [4, 0, mask])
    }

    @Test func addingAFavoriteWritesTheMergedMask() async throws {
        let transport = ScriptedTransport(script: [
            [Self.favorites(0b0001)],
            [Self.favorites(0b0101)],
            [Self.favorites(0b0101)],
        ])
        let device = try await connectedDevice(on: transport)
        let result = try await device.setFavorite(2, true)
        #expect(try result == FavoriteModes(slotCount: 4, slots: [0, 2]))
        #expect(await transport.writes == [
            frame(.favorites, .get),
            frame(.favorites, .setGet, [4, 0, 0b0101]),
            frame(.favorites, .get),
        ])
        await device.close()
    }

    @Test func removingAFavoriteWritesTheReducedMask() async throws {
        let transport = ScriptedTransport(script: [
            [Self.favorites(0b0101)],
            [Self.favorites(0b0100)],
            [Self.favorites(0b0100)],
        ])
        let device = try await connectedDevice(on: transport)
        let result = try await device.setFavorite(0, false)
        #expect(try result == FavoriteModes(slotCount: 4, slots: [2]))
        #expect(await transport.writes[1] == frame(.favorites, .setGet, [4, 0, 0b0100]))
        await device.close()
    }

    @Test func favoriteFailsVerificationWhenReadBackDisagrees() async throws {
        let transport = ScriptedTransport(script: [
            [Self.favorites(0b0001)],
            [Self.favorites(0b0001)],
            [Self.favorites(0b0001)],
        ])
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.verificationFailed(.feature(.favorites))) {
            try await device.setFavorite(2, true)
        }
        await device.close()
    }

    @Test func slotBeyondDeviceSlotCountIsRejectedBeforeWriting() async throws {
        let transport = ScriptedTransport(script: [[Self.favorites(0b0001)]])
        let device = try await connectedDevice(on: transport)
        await #expect(throws: BoseError.self) { try await device.setFavorite(7, true) }
        #expect(await transport.writes == [frame(.favorites, .get)])
        await device.close()
    }
}
