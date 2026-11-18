import Testing
import Foundation
import BoseKitEngine
@testable import BoseKit

@MainActor
struct BoseKitTests {
    @Test func semanticResourcesResolveInBothLanguages() {
        var title = L10n.Menu.title
        title.locale = Locale(identifier: "en")
        #expect(String(localized: title) == "Menu Bar")
        title.locale = Locale(identifier: "ko")
        #expect(String(localized: title) == "메뉴 막대")
    }

    @Test(arguments: [false, true])
    func alwaysVisibleWhenAutoHideDisabled(connected: Bool) {
        #expect(BoseAppModel.shouldShowMenu(hide: false, hasConnectedDevice: connected))
    }

    @Test func autoHideTracksConnectionAvailability() {
        #expect(!BoseAppModel.shouldShowMenu(hide: true, hasConnectedDevice: false))
        #expect(BoseAppModel.shouldShowMenu(hide: true, hasConnectedDevice: true))
    }

    @Test func unconfiguredPresetsRemainSelectableButEmptyCustomSlotsDoNot() throws {
        let profile = try #require(DeviceRegistry.standard().profile(productID: 0x4066))
        let preset = mode(slot: 1, configured: false)
        let empty = mode(slot: 4, configured: false)
        let namedNone = mode(slot: 3, configured: true)
        let policy = try #require(profile.modePolicy)
        #expect(policy.isSelectable(preset))
        #expect(!policy.isSelectable(empty))
        #expect(policy.isSelectable(namedNone))
        #expect(namedNone.displayName == "WORK")
    }

    @Test func customModeNamesFollowVoicePromptsAndPreserveUnknownNames() {
        let custom = ModeConfiguration(id: 3, prompt: 12, name: "Old custom name", editable: true,
            configured: true, favorite: false, audio: AudioSettings(cnc: 5), rawPayload: [])
        let unknown = ModeConfiguration(id: 4, prompt: 999, name: "Future mode", editable: true,
            configured: true, favorite: false, audio: AudioSettings(cnc: 5), rawPayload: [])
        let preset = ModeConfiguration(id: 0, prompt: 1, name: "Quiet", editable: false,
            configured: true, favorite: true, audio: AudioSettings(cnc: 0), rawPayload: [])
        #expect(custom.displayName == "MUSIC")
        #expect(unknown.displayName == "Future mode")
        #expect(preset.displayName == "Quiet")
    }

    @Test func capabilityGatingDistinguishesLegacyAndUltra() throws {
        let registry = try DeviceRegistry.standard()
        let legacy = DeviceController(id: "legacy", name: "QC35", profile: try #require(registry.profile(productID: 0x400c)))
        let ultra = DeviceController(id: "ultra", name: "Ultra", profile: try #require(registry.profile(productID: 0x4066)))
        #expect(legacy.supports(.anr, write: true))
        #expect(!legacy.supports(.spatialAudio, write: true))
        #expect(ultra.supports(.spatialAudio, write: true))
        #expect(!ultra.supports(.cnc, write: true))
        #expect(!ultra.supports(.audioSettings))
        #expect(!ultra.canEditAudio)
    }

    @Test func staleNativeConnectionDoesNotKeepMenuVisible() throws {
        let profile = try #require(DeviceRegistry.standard().profile(productID: 0x4066))
        let model = BoseAppModel()
        let first = DeviceController(id: "one", name: "One", profile: profile)
        let second = DeviceController(id: "two", name: "Two", profile: profile)
        model.devices = [first, second]
        let original = model.hideWhenUnavailable
        defer { model.hideWhenUnavailable = original }
        model.hideWhenUnavailable = true
        #expect(!model.menuInserted)
        second.nativeConnected = true
        #expect(!model.menuInserted)
        second.nativeConnected = false
        #expect(!model.menuInserted)
    }

    private func mode(slot: UInt8, configured: Bool) -> ModeConfiguration {
        ModeConfiguration(id: slot, prompt: 11, name: "None", editable: slot > 2,
                          configured: configured, favorite: false, audio: AudioSettings(cnc: 5), rawPayload: [])
    }
}
