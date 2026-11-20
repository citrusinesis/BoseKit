import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct DeviceDiscoveryTests {
    @Test func unpairedDeviceIsClosedAndRemoved() async throws {
        let paired = try PairedHeadsets(["one", "two"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        let one = try paired.controller("one")
        try await paired.connect("one")
        paired.pair(["two"])
        try await paired.model.syncPairedDevices()
        #expect(paired.model.devices.map(\.id) == ["two"])
        #expect(!one.connected)
        #expect(try await paired.headset("one").closes > 0)
    }

    @Test func failedListingKeepsTheDeviceList() async throws {
        let paired = try PairedHeadsets(["one", "two"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        let devices = paired.model.devices
        try await paired.connect("one")
        paired.listing.fail()
        await #expect(throws: PairedDeviceListingError.systemListUnavailable) {
            try await paired.model.syncPairedDevices()
        }
        #expect(paired.model.devices.map(ObjectIdentifier.init) == devices.map(ObjectIdentifier.init))
        #expect(try paired.controller("one").connected)
        #expect(try await paired.headset("one").closes == 0)
        await paired.disconnectAll()
    }

    @Test func duplicateAddressEntriesShareOneController() async throws {
        let paired = try PairedHeadsets(["one"], defaults: try isolatedDefaults())
        paired.listing.set([PairedHeadsets.entry("one"), PairedHeadsets.entry("one", identity: nil),
                            PairedHeadsets.entry("one")])
        try await paired.model.syncPairedDevices()
        let one = try paired.controller("one")
        try await paired.connect("one")
        paired.listing.set([PairedHeadsets.entry("one", identity: nil), PairedHeadsets.entry("one")])
        try await paired.model.syncPairedDevices()
        #expect(paired.model.devices.count == 1)
        #expect(try paired.controller("one") === one)
        #expect(one.connected)
        await paired.disconnectAll()
    }

    @Test func systemConnectionFlagDoesNotTouchTheControlSession() async throws {
        let paired = try PairedHeadsets(["one"], defaults: try isolatedDefaults())
        try await paired.model.syncPairedDevices()
        try await paired.connect("one")
        paired.listing.set([PairedHeadsets.entry("one", isConnected: false)])
        try await paired.model.syncPairedDevices()
        #expect(try paired.controller("one").connected)
        #expect(try await paired.headset("one").closes == 0)
        await paired.disconnectAll()
    }
}
