import SwiftUI
import BoseKitEngine

struct AppPreferencesView: View {
    @Bindable var model: BoseAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: .menuTitle) {
                SettingsToggle(title: .menuHideWhenUnavailable, isOn: $model.hideWhenUnavailable)
                    .accessibilityIdentifier("hideWhenUnavailable")
                SettingsFootnote(.menuHiddenHelp)
                Divider()
                SettingsToggle(title: .menuShowBattery, isOn: $model.showBattery)
                    .accessibilityIdentifier("showBattery")
            }
            SettingsSection(title: .connectionTitle) {
                Text(.connectionDiscoveryHelp)
                    .foregroundStyle(.secondary)
                OpenBluetoothSettingsButton()
                if let device = model.selected {
                    Divider()
                    ConnectionToggleButton(device: device)
                }
                if let error = model.discoveryError {
                    Text(error.message).foregroundStyle(.orange)
                }
                SettingsFootnote(.connectionRefreshHelp)
            }
        }
    }
}

private struct ConnectionToggleButton: View {
    let device: DeviceController

    var body: some View {
        Button(device.isSuspended ? .connectionResume : .connectionDisconnect) {
            Task {
                if device.isSuspended { await device.connect() } else { await device.disconnect() }
            }
        }
        .disabled(device.busy || device.connecting)
    }
}

#Preview("App Preferences") {
    ScrollView {
        AppPreferencesView(model: BoseAppModel())
            .settingsContentStyle()
            .padding(20)
    }
    .frame(width: 420, height: 540)
}
