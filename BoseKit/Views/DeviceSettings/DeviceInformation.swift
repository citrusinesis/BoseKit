import SwiftUI
import BoseKitEngine

struct DeviceInformation: View {
    let device: DeviceController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InformationRow(L10n.Device.model, value: device.modelName ?? device.profile.name)
            if let firmware = device.firmware {
                InformationRow(L10n.Device.firmware, value: firmware)
            }
            if let serial = device.serial {
                InformationRow(L10n.Device.serialNumber, value: serial)
            }
            InformationRow(L10n.Device.bluetoothAddress, value: device.id)
            if let components = device.battery?.components {
                ForEach(components.keys.sorted(), id: \.self) { component in
                    InformationRow(title: component.title) {
                        Text(L10n.Device.batteryPercentage(components[component] ?? 0))
                    }
                }
            }
            if let source = device.source {
                InformationRow(L10n.Device.audioSource, value: source.kind.title)
                if let address = source.bluetoothAddress {
                    Text(address.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !device.unavailable.isEmpty {
                SettingsFootnote(L10n.Device.unavailableHelp)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
}
