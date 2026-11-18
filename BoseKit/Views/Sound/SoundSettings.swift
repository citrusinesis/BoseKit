import SwiftUI
import BoseKitEngine

struct SoundSettings: View {
    let device: DeviceController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if device.supports(.modes) {
                ModesControls(device: device)
            }
            if device.hasListeningControls {
                SettingsSection(title: .commonSound) {
                    ListeningControls(device: device)
                }
            }
            if !device.equalizer.isEmpty {
                SettingsSection(title: .soundEqualizer) {
                    EqualizerControls(device: device)
                }
            }
            if device.hasPlaybackSettings {
                PlaybackSettings(device: device)
            }
            if isEmpty {
                Text(.soundEmpty).foregroundStyle(.secondary)
            }
        }
    }

    private var isEmpty: Bool {
        !device.supports(.modes) && !device.hasListeningControls
            && device.equalizer.isEmpty && !device.hasPlaybackSettings
    }
}
