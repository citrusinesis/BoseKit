import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct DeviceSelectionTests {
    @Test func firstDeviceIsSelectedWithoutAStoredSelection() async throws {
        let paired = try PairedHeadsets(["one", "two"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        #expect(paired.model.selectedID == "one")
    }

    @Test func connectedDeviceIsSelectedWhenTheSelectionIsDisconnected() async throws {
        let paired = try PairedHeadsets(["one", "two"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        try await paired.connect("two")
        #expect(paired.model.selectedID == "two")
        await paired.disconnectAll()
    }

    @Test func connectingAnotherDeviceKeepsAConnectedSelection() async throws {
        let paired = try PairedHeadsets(["one", "two"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        try await paired.connect("one", "two")
        #expect(paired.model.selectedID == "one")
        await paired.disconnectAll()
    }

    @Test func lostSelectionMovesToAConnectedDevice() async throws {
        let paired = try PairedHeadsets(["one", "two", "three"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        try await paired.connect("one", "two", "three")
        paired.model.selectedID = "three"
        try await paired.headset("three").close()
        try await paired.controller("three").refresh()
        #expect(try !paired.controller("three").connected)
        #expect(paired.model.selectedID == "one")
        await paired.disconnectAll()
    }

    @Test func lostSelectionStaysWithoutAnotherConnectedDevice() async throws {
        let paired = try PairedHeadsets(["one", "two"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        paired.model.selectedID = "two"
        try await paired.connect("two")
        try await paired.headset("two").close()
        try await paired.controller("two").refresh()
        #expect(paired.model.selectedID == "two")
    }

    @Test func userPickedDisconnectedDeviceStaysSelected() async throws {
        let paired = try PairedHeadsets(["one", "two"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        try await paired.connect("one")
        paired.model.selectedID = "two"
        try await paired.model.syncPairedDevices()
        #expect(paired.model.selectedID == "two")
        try await paired.headset("one").close()
        try await paired.controller("one").refresh()
        #expect(try !paired.controller("one").connected)
        #expect(paired.model.selectedID == "two")
    }

    @Test func selectionIsRestoredFromTheInjectedDefaults() async throws {
        let defaults = try isolatedDefaults()
        let first = try PairedHeadsets(["one", "two"], defaults: defaults)
        try await first.model.syncPairedDevices()
        first.model.selectedID = "two"
        let relaunched = try PairedHeadsets(["one", "two"], defaults: defaults)
        #expect(relaunched.model.selectedID == "two")
        try await relaunched.model.syncPairedDevices()
        #expect(relaunched.model.selectedID == "two")
        #expect(relaunched.model.selected?.id == "two")
    }

    @Test func automaticSelectionIsPersisted() async throws {
        let defaults = try isolatedDefaults()
        let first = try PairedHeadsets(["one", "two"], defaults: defaults)
        try await first.model.syncPairedDevices()
        try await first.connect("two")
        await first.disconnectAll()
        let relaunched = try PairedHeadsets(["one", "two"], defaults: defaults)
        try await relaunched.model.syncPairedDevices()
        #expect(relaunched.model.selectedID == "two")
    }

    @Test func storedSelectionOfAnUnpairedDeviceFallsBackToTheFirstDevice() async throws {
        let defaults = try isolatedDefaults()
        let first = try PairedHeadsets(["one", "two", "gone"], defaults: defaults)
        try await first.model.syncPairedDevices()
        first.model.selectedID = "gone"
        let relaunched = try PairedHeadsets(["one", "two"], defaults: defaults)
        try await relaunched.model.syncPairedDevices()
        #expect(relaunched.model.selectedID == "one")
    }

    @Test func removingTheSelectedDevicePrefersAConnectedDevice() async throws {
        let paired = try PairedHeadsets(["one", "two", "three"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        try await paired.connect("three")
        paired.model.selectedID = "one"
        paired.pair(["two", "three"])
        try await paired.model.syncPairedDevices()
        #expect(paired.model.selectedID == "three")
        await paired.disconnectAll()
    }

    @Test func removingTheSelectedDeviceFallsBackToTheFirstDevice() async throws {
        let paired = try PairedHeadsets(["one", "two", "three"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        paired.model.selectedID = "two"
        paired.pair(["one", "three"])
        try await paired.model.syncPairedDevices()
        #expect(paired.model.selectedID == "one")
    }

    @Test func removingTheConnectedSelectionMovesToAnotherConnectedDevice() async throws {
        let paired = try PairedHeadsets(["one", "two", "three"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        try await paired.connect("two", "three")
        paired.model.selectedID = "two"
        paired.pair(["one", "three"])
        try await paired.model.syncPairedDevices()
        #expect(paired.model.selectedID == "three")
        await paired.disconnectAll()
    }
}
