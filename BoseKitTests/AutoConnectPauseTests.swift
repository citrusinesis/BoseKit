import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct AutoConnectPauseTests {
    @Test func userDisconnectSurvivesRelaunch() async throws {
        let defaults = try isolatedDefaults()
        let first = try PairedHeadsets(["one", "two"], defaults: defaults)
        try await first.model.syncPairedDevices()
        try await first.connect("one")
        try await first.controller("one").disconnect()
        let relaunched = try PairedHeadsets(["one", "two"], defaults: defaults)
        try await relaunched.model.syncPairedDevices()
        let one = try relaunched.controller("one")
        #expect(one.autoConnectPause == .userDisconnected)
        #expect(try relaunched.controller("two").autoConnectPause == nil)
        await one.maintain()
        #expect(!one.connected)
        #expect(try await relaunched.headset("one").requests.isEmpty)
    }

    @Test func explicitConnectClearsTheStoredDisconnect() async throws {
        let defaults = try isolatedDefaults()
        let first = try PairedHeadsets(["one"], defaults: defaults)
        try await first.model.syncPairedDevices()
        try await first.controller("one").disconnect()
        let second = try PairedHeadsets(["one"], defaults: defaults)
        try await second.model.syncPairedDevices()
        try await second.connect("one")
        #expect(try second.controller("one").autoConnectPause == nil)
        await second.disconnectAll()
        let third = try PairedHeadsets(["one"], defaults: defaults)
        try await third.model.syncPairedDevices()
        #expect(try third.controller("one").autoConnectPause == nil)
    }

    @Test func powerOffPauseIsNotPersisted() async throws {
        let defaults = try isolatedDefaults()
        let first = try PairedHeadsets(["one"], defaults: defaults, features: [.battery: .read, .power: .write])
        try await first.model.syncPairedDevices()
        try await first.connect("one")
        try await first.controller("one").powerOff()
        #expect(try first.controller("one").autoConnectPause == .poweredOff)
        let relaunched = try PairedHeadsets(["one"], defaults: defaults)
        try await relaunched.model.syncPairedDevices()
        #expect(try relaunched.controller("one").autoConnectPause == nil)
    }

    @Test func unpairedDeviceForgetsTheStoredDisconnect() async throws {
        let defaults = try isolatedDefaults()
        let first = try PairedHeadsets(["one", "two"], defaults: defaults)
        try await first.model.syncPairedDevices()
        try await first.controller("one").disconnect()
        first.pair(["two"])
        try await first.model.syncPairedDevices()
        let relaunched = try PairedHeadsets(["one", "two"], defaults: defaults)
        try await relaunched.model.syncPairedDevices()
        #expect(try relaunched.controller("one").autoConnectPause == nil)
    }

    @Test func deviceUnpairedWhileTheAppWasClosedForgetsTheStoredDisconnect() async throws {
        let defaults = try isolatedDefaults()
        let first = try PairedHeadsets(["one", "two"], defaults: defaults)
        try await first.model.syncPairedDevices()
        try await first.controller("one").disconnect()
        let unpaired = try PairedHeadsets(["two"], defaults: defaults)
        try await unpaired.model.syncPairedDevices()
        let repaired = try PairedHeadsets(["one", "two"], defaults: defaults)
        try await repaired.model.syncPairedDevices()
        #expect(try repaired.controller("one").autoConnectPause == nil)
    }
}
