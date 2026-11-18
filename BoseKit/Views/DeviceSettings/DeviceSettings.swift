import SwiftUI
import BoseKitEngine

struct DeviceSettings: View {
    let device: DeviceController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if device.supports(.name, write: true) {
                DeviceNameSettings(device: device)
            }
            if device.hasConnectionSettings {
                ConnectionSettings(device: device)
            }
            if !device.sourceDevices.isEmpty {
                SourceDeviceList(device: device)
            }
            if device.buttons != nil {
                SettingsSection(title: L10n.Device.shortcut) {
                    ShortcutSettings(device: device)
                }
            }
            if device.voicePrompts != nil {
                SettingsSection(title: L10n.Device.voicePrompts) {
                    VoicePromptSettings(device: device)
                        .disabled(!device.supports(.voicePrompts, write: true))
                }
            }
            SettingsSection(title: L10n.Device.information) {
                DeviceInformation(device: device)
            }
            if device.supports(.power, write: true) {
                PowerOffButton(device: device)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

private struct DeviceNameSettings: View {
    let device: DeviceController
    @State private var newName = ""

    var body: some View {
        SettingsSection(title: L10n.Device.name) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField(L10n.Device.name, text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button(L10n.Common.save) { device.rename(to: newName) }
                    .disabled(!isValid)
            }
        }
        .onAppear { newName = device.name }
    }

    private var isValid: Bool {
        !newName.isEmpty && newName.utf8.count <= BoseFeatures.maximumNameLength && newName != device.name
    }
}

private struct PowerOffButton: View {
    let device: DeviceController
    @State private var confirming = false

    var body: some View {
        Button(L10n.Device.powerOff, systemImage: "power", role: .destructive) { confirming = true }
            .confirmationDialog(L10n.Device.powerOffConfirmation, isPresented: $confirming,
                                titleVisibility: .visible) {
                Button(L10n.Device.confirmPowerOff, role: .destructive) {
                    Task { await device.powerOff() }
                }
            } message: {
                Text(L10n.Device.powerOffHelp)
            }
    }
}
