import SwiftUI
import BoseKitEngine

struct AppPreferencesView: View {
    @Bindable var model: BoseAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: L10n.Menu.title) {
                SettingsToggle(title: L10n.Menu.hideWhenUnavailable, isOn: $model.hideWhenUnavailable)
                    .accessibilityIdentifier("hideWhenUnavailable")
                SettingsFootnote(L10n.Menu.hiddenHelp)
                Divider()
                SettingsToggle(title: L10n.Menu.showBattery, isOn: $model.showBattery)
                    .accessibilityIdentifier("showBattery")
            }
            SettingsSection(title: L10n.Connection.title) {
                Text(L10n.Connection.discoveryHelp)
                    .foregroundStyle(.secondary)
                OpenBluetoothSettingsButton()
                if let device = model.selected {
                    Divider()
                    ConnectionToggleButton(device: device)
                }
                if let error = model.discoveryError {
                    Text(error).foregroundStyle(.orange)
                }
                SettingsFootnote(L10n.Connection.refreshHelp)
            }
        }
    }
}

private struct ConnectionToggleButton: View {
    let device: DeviceController

    var body: some View {
        Button(device.isSuspended ? L10n.Connection.resume : L10n.Connection.disconnect) {
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
