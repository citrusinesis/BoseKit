import SwiftUI
import BoseKitEngine

struct ListeningControls: View {
    @Bindable var device: DeviceController
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if compact, device.shownMode != nil, !device.selectableModes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(.modesTitle, systemImage: "waveform").font(.headline)
                    Picker(.modesCurrent, selection: $device.currentModeSelection) {
                        ForEach(device.selectableModes) { Text($0.displayName).tag($0.id) }
                    }
                    .disabled(!device.supports(.currentMode, write: true))
                }
            }
            if let audio = device.shownAudio, !compact || device.canEditAudio {
                AudioControls(device: device, audio: audio)
            } else if let cnc = device.cnc, let level = device.shownCNC, !compact || device.canEditAudio {
                ValueSlider(title: .soundAmbient, value: Double(level),
                            range: 0...min(Double(cnc.maximum), CNCLevel.sliderRange.upperBound),
                            revision: device.refreshRevision, editingChanged: device.setEditing) {
                    device.setCNC(CNCLevel(sliderValue: $0))
                }
                .disabled(!device.supports(.cnc, write: true))
            }
            if device.anr != nil {
                SettingsPicker(title: .soundNoiseCancellation, selection: $device.anrSelection) {
                    ForEach(ANRLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(!device.supports(.anr, write: true))
            }
        }
    }
}
