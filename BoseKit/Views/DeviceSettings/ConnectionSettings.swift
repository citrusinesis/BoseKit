import SwiftUI
import BoseKitEngine

struct ConnectionSettings: View {
    @Bindable var device: DeviceController

    var body: some View {
        SettingsSection(title: .connectionTitle) {
            if let multipoint = device.multipoint {
                SettingsToggle(title: .deviceMultipoint, isOn: $device.multipointEnabled)
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
            Button(isPairing ? .deviceStopPairing : .devicePairing,
                   systemImage: isPairing ? "xmark.circle" : "plus.circle", action: action)
            if isPairing {
                SettingsFootnote(.devicePairingHelp)
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
                            Text(.deviceAudioSource)
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
                    Text(.deviceSourceUnknown).foregroundStyle(.secondary)
                }
                SettingsFootnote(.deviceMultipointListHelp)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } label: {
            Text(.deviceConnectionDetails)
        }
    }
}

private struct RoutingControls: View {
    let device: DeviceController
    @State private var address = ""

    var body: some View {
        let parsed = BluetoothAddress(string: address)
        VStack(alignment: .leading, spacing: 8) {
            Text(.deviceSwitchSource)
            TextField(.deviceSourceAddress, text: $address)
                .textFieldStyle(.roundedBorder)
            Button(.deviceConfirmSwitchSource) {
                if let parsed { device.routeAudio(to: parsed) }
            }
            .disabled(parsed == nil)
        }
    }
}

#Preview("Pairing") {
    SettingsSection(title: .connectionTitle) {
        PairingControls(isPairing: true) {}
    }
    .settingsContentStyle()
    .padding(20)
    .frame(width: 420)
}
