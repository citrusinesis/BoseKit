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
                SettingsSection(title: .deviceShortcut) {
                    ShortcutSettings(device: device)
                }
            }
            if device.voicePrompts != nil {
                SettingsSection(title: .deviceVoicePrompts) {
                    VoicePromptSettings(device: device)
                        .disabled(!device.supports(.voicePrompts, write: true))
                }
            }
            SettingsSection(title: .deviceInformation) {
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
        SettingsSection(title: .deviceName) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField(.deviceName, text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button(.commonSave) { device.rename(to: newName) }
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
        Button(.devicePowerOff, systemImage: "power", role: .destructive) { confirming = true }
            .confirmationDialog(.devicePowerOffConfirmation, isPresented: $confirming,
                                titleVisibility: .visible) {
                Button(.deviceConfirmPowerOff, role: .destructive) {
                    Task { await device.powerOff() }
                }
            } message: {
                Text(.devicePowerOffHelp)
            }
    }
}
