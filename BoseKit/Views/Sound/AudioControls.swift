import SwiftUI
import BoseKitEngine

struct AudioControls: View {
    @Bindable var device: DeviceController
    let audio: AudioSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                ValueSlider(title: L10n.Sound.ambient, value: Double(audio.cnc), range: 0...10,
                            revision: device.refreshRevision, editingChanged: device.setEditing) {
                    device.setCNC(UInt8($0))
                }
                .disabled(!device.canEditAudio || audio.windBlock || !device.canAdjustCNC)
                NoiseControlRangeLabels()
            }
            if !device.canEditAudio && device.profile.noiseControl == .modeConfiguration {
                Label(L10n.Sound.presetHelp, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if device.supports(.spatialAudio) {
                SpatialAudioPicker(selection: $device.spatialAudioSelection)
                    .disabled(!device.canEditAudio || !device.supports(.spatialAudio, write: true))
            }
            if device.supports(.windBlock) {
                SettingsToggle(title: L10n.Sound.windBlock, isOn: $device.windBlockEnabled)
                    .disabled(!device.canEditAudio || !device.supports(.windBlock, write: true))
                if audio.windBlock {
                    SettingsFootnote(L10n.Sound.windBlockHelp)
                }
            }
            if audio.ancEnabled != nil, device.supports(.ancToggle, write: true) {
                SettingsToggle(title: L10n.Sound.noiseCancellation, isOn: $device.ancEnabled)
            }
            if device.supports(.audioSettings, write: true) {
                SettingsToggle(title: L10n.Sound.automaticAmbient, isOn: $device.automaticCNCEnabled)
            }
        }
    }
}
