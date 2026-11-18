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

    @Test func staleNativeConnectionDoesNotKeepMenuVisible() throws {
        let profile = HeadsetFixture().profile
        let model = BoseAppModel(defaults: try isolatedDefaults())
        let second = DeviceController(id: "two", name: "Two", profile: profile)
        model.devices = [DeviceController(id: "one", name: "One", profile: profile), second]
        model.hideWhenUnavailable = true
        #expect(!model.menuInserted)
        second.nativeConnected = true
        #expect(!model.menuInserted)
        second.nativeConnected = false
        #expect(!model.menuInserted)
    }

    @Test func menuFollowsLiveConnectionAndBatteryWithoutPollingVisibility() async throws {
        let fixture = HeadsetFixture()
        let model = BoseAppModel(defaults: try isolatedDefaults())
        model.devices = [DeviceController(id: "offline", name: "Offline", profile: fixture.profile), fixture.controller]
        model.selectedID = "offline"
        model.hideWhenUnavailable = true
        model.showBattery = true
        #expect(!model.menuInserted)
        #expect(model.menuBatteryPercentage == nil)
        await fixture.controller.connect()
        #expect(model.menuInserted)
        #expect(model.menuBatteryPercentage == 90)
        model.showBattery = false
        #expect(model.menuBatteryPercentage == nil)
        model.showBattery = true
        fixture.controller.nativeConnected = true
        await fixture.controller.disconnect()
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
