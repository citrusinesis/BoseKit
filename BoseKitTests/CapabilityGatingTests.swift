import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct CapabilityGatingTests {
    @Test func legacyAndUltraExposeDifferentControls() {
        let legacy = DeviceController(id: "legacy", name: "QC35", profile: .qc35)
        let ultra = DeviceController(id: "ultra", name: "Ultra", profile: .lonestarr)
        #expect(legacy.supports(.anr, write: true))
        #expect(!legacy.supports(.spatialAudio, write: true))
        #expect(ultra.supports(.spatialAudio, write: true))
        #expect(!ultra.supports(.cnc, write: true))
        #expect(!ultra.supports(.audioSettings))
        #expect(!ultra.canEditAudio)
    }

    @Test func unconfiguredPresetsRemainSelectableButEmptyCustomSlotsDoNot() throws {
        let policy = try #require(DeviceProfile.lonestarr.modePolicy)
        let preset = mode(slot: 1, configured: false)
        let empty = mode(slot: 4, configured: false)
        let namedNone = mode(slot: 3, configured: true)
        #expect(policy.isSelectable(preset))
        #expect(!policy.isSelectable(empty))
        #expect(policy.isSelectable(namedNone))
        #expect(namedNone.displayName == "WORK")
    }

    private func mode(slot: UInt8, configured: Bool) -> ModeConfiguration {
        ModeConfiguration(id: slot, prompt: .work, name: ModeConfiguration.emptyName.rawValue,
                          editable: slot > 2, configured: configured, favorite: false,
                          audio: AudioSettings(cnc: 5), rawPayload: [])
    }
}
