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
                SettingsSection(title: L10n.Common.sound) {
                    ListeningControls(device: device)
                }
            }
            if !device.equalizer.isEmpty {
                SettingsSection(title: L10n.Sound.equalizer) {
                    EqualizerControls(device: device)
                }
            }
            if device.hasPlaybackSettings {
                PlaybackSettings(device: device)
            }
            if isEmpty {
                Text(L10n.Sound.empty).foregroundStyle(.secondary)
            }
        }
    }

    private var isEmpty: Bool {
        !device.supports(.modes) && !device.hasListeningControls
            && device.equalizer.isEmpty && !device.hasPlaybackSettings
    }
}
