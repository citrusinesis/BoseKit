import SwiftUI
import BoseKitEngine

struct ConnectionSettings: View {
    @Bindable var device: DeviceController

    var body: some View {
        SettingsSection(title: L10n.Connection.title) {
            if let multipoint = device.multipoint {
                SettingsToggle(title: L10n.Device.multipoint, isOn: $device.multipointEnabled)
                    .disabled(!device.supports(.multipoint, write: true))
                if multipoint && device.sourceDevices.isEmpty {
                    SourceDetails(source: device.source)
                }
            }
            if let pairing = device.pairing {
                if device.multipoint != nil { Divider() }
                PairingControls(isPairing: pairing) { device.setPairing(!pairing) }
                    .disabled(!device.supports(.pairing, write: true))
            }
            if device.supports(.routing, write: true) && device.sourceDevices.isEmpty {
                Divider()
                RoutingControls(device: device)
            }
        }
    }
}

private struct PairingControls: View {
    let isPairing: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(isPairing ? L10n.Device.stopPairing : L10n.Device.pairing,
                   systemImage: isPairing ? "xmark.circle" : "plus.circle", action: action)
            if isPairing {
                SettingsFootnote(L10n.Device.pairingHelp)
            }
        }
    }
}

private struct SourceDetails: View {
    let source: AudioSource?
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                if let source {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: source.kind.systemImage)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Device.audioSource)
                            Text(source.kind.title).foregroundStyle(.secondary)
                            if let address = source.bluetoothAddress {
                                Text(address.description)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                } else {
                    Text(L10n.Device.sourceUnknown).foregroundStyle(.secondary)
                }
                SettingsFootnote(L10n.Device.multipointListHelp)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } label: {
            Text(L10n.Device.connectionDetails)
        }
    }
}

private struct RoutingControls: View {
    let device: DeviceController
    @State private var address = ""

    var body: some View {
        let parsed = BluetoothAddress(string: address)
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Device.switchSource)
            TextField(L10n.Device.sourceAddress, text: $address)
                .textFieldStyle(.roundedBorder)
            Button(L10n.Device.confirmSwitchSource) {
                if let parsed { device.routeAudio(to: parsed) }
            }
            .disabled(parsed == nil)
        }
    }
}

#Preview("Pairing") {
    SettingsSection(title: L10n.Connection.title) {
        PairingControls(isPairing: true) {}
    }
    .settingsContentStyle()
    .padding(20)
    .frame(width: 420)
}
