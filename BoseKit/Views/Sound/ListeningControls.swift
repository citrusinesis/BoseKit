import SwiftUI
import BoseKitEngine

struct ListeningControls: View {
    @Bindable var device: DeviceController
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if compact, device.currentMode != nil, !device.selectableModes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(L10n.Modes.title, systemImage: "waveform").font(.headline)
                    Picker(L10n.Modes.current, selection: $device.currentModeSelection) {
                        ForEach(device.selectableModes) { Text($0.displayName).tag($0.id) }
                    }
                    .disabled(!device.supports(.currentMode, write: true))
                }
            }
            if let audio = device.audio, !compact || device.canEditAudio {
                AudioControls(device: device, audio: audio)
            } else if let cnc = device.cnc, !compact || device.canEditAudio {
                ValueSlider(title: L10n.Sound.ambient, value: Double(cnc.current), range: 0...Double(cnc.maximum),
                            revision: device.refreshRevision, editingChanged: device.setEditing) {
                    device.setCNC(UInt8($0))
                }
                .disabled(!device.supports(.cnc, write: true))
            }
            if device.anr != nil {
                SettingsPicker(title: L10n.Sound.noiseCancellation, selection: $device.anrSelection) {
                    ForEach(ANRLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(!device.supports(.anr, write: true))
            }
        }
    }
}
