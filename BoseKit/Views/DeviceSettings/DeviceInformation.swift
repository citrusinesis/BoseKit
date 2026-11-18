import SwiftUI
import BoseKitEngine

struct DeviceInformation: View {
    let device: DeviceController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InformationRow(.deviceModel, value: device.modelName ?? device.profile.name)
            if let firmware = device.firmware {
                InformationRow(.deviceFirmware, value: firmware)
            }
            if let serial = device.serial {
                InformationRow(.deviceSerialNumber, value: serial)
            }
            InformationRow(.deviceBluetoothAddress, value: device.id)
            if let components = device.battery?.components {
                ForEach(components.sorted { $0.key < $1.key }, id: \.key) { component, percentage in
                    InformationRow(title: component.title) {
                        Text(.deviceBatteryPercentage(UInt32(percentage)))
                    }
                }
            }
            if let source = device.source {
                InformationRow(.deviceAudioSource, value: source.kind.title)
                if let address = source.bluetoothAddress {
                    Text(address.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !device.unavailable.isEmpty {
                SettingsFootnote(.deviceUnavailableHelp)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
}
