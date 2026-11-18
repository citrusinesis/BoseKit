import SwiftUI
import BoseKitEngine

struct AudioControls: View {
    @Bindable var device: DeviceController
    let audio: AudioSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                ValueSlider(title: .soundAmbient, value: Double(audio.cnc), range: 0...10,
                            revision: device.refreshRevision, editingChanged: device.setEditing) {
                    device.setCNC(UInt8($0))
                }
                .disabled(!device.canEditAudio || audio.windBlock || !device.canAdjustCNC)
                NoiseControlRangeLabels()
            }
            if !device.canEditAudio && device.profile.noiseControl == .modeConfiguration {
                Label(.soundPresetHelp, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if device.supports(.spatialAudio) {
                SpatialAudioPicker(selection: $device.spatialAudioSelection)
                    .disabled(!device.canEditAudio || !device.supports(.spatialAudio, write: true))
            }
            if device.supports(.windBlock) {
                SettingsToggle(title: .soundWindBlock, isOn: $device.windBlockEnabled)
                    .disabled(!device.canEditAudio || !device.supports(.windBlock, write: true))
                if audio.windBlock {
                    SettingsFootnote(.soundWindBlockHelp)
                }
            }
            if audio.ancEnabled != nil, device.supports(.ancToggle, write: true) {
                SettingsToggle(title: .soundNoiseCancellation, isOn: $device.ancEnabled)
            }
            if device.supports(.audioSettings, write: true) {
                SettingsToggle(title: .soundAutomaticAmbient, isOn: $device.automaticCNCEnabled)
            }
        }
    }
}
