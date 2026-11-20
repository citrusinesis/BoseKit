import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct MenuVisibilityTests {
    @Test(arguments: [false, true])
    func alwaysVisibleWhenAutoHideDisabled(connected: Bool) {
        #expect(BoseAppModel.shouldShowMenu(hide: false, hasConnectedDevice: connected))
    }

    @Test func autoHideTracksConnectionAvailability() {
        #expect(!BoseAppModel.shouldShowMenu(hide: true, hasConnectedDevice: false))
        #expect(BoseAppModel.shouldShowMenu(hide: true, hasConnectedDevice: true))
    }

    @Test func systemConnectionFlagDoesNotKeepMenuVisible() async throws {
        let paired = try PairedHeadsets(["one", "two"], defaults: try isolatedDefaults())
        let model = paired.model
        paired.listing.set([PairedHeadsets.entry("one"), PairedHeadsets.entry("two", isConnected: true)])
        try await model.syncPairedDevices()
        model.hideWhenUnavailable = true
        #expect(!model.menuInserted)
    }

    @Test func menuFollowsLiveConnectionAndBatteryWithoutPollingVisibility() async throws {
        let paired = try PairedHeadsets(["offline", "online"], defaults: try isolatedDefaults())
        let model = paired.model
        try await model.syncPairedDevices()
        model.selectedID = "offline"
        model.hideWhenUnavailable = true
        model.showBattery = true
        #expect(!model.menuInserted)
        #expect(model.menuBatteryPercentage == nil)
        let online = try paired.controller("online")
        await online.connect()
        #expect(model.menuInserted)
        #expect(model.menuBatteryPercentage == 90)
        model.showBattery = false
        #expect(model.menuBatteryPercentage == nil)
        model.showBattery = true
        await online.disconnect()
        #expect(!model.menuInserted)
        #expect(model.menuBatteryPercentage == nil)
    }

    @Test func menuPreferencesPersistInTheInjectedDefaults() throws {
        let defaults = try isolatedDefaults()
        let model = BoseAppModel(defaults: defaults)
        #expect(!model.hideWhenUnavailable)
        #expect(!model.showBattery)
        model.hideWhenUnavailable = true
        model.showBattery = true
        let relaunched = BoseAppModel(defaults: defaults)
        #expect(relaunched.hideWhenUnavailable)
        #expect(relaunched.showBattery)
    }
}
