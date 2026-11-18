import SwiftUI
import BoseKitEngine

struct SourceDeviceList: View {
    let device: DeviceController

    var body: some View {
        let canSwitch = device.supports(.routing, write: true)
        SettingsSection(title: .deviceSourceDevices) {
            ForEach(device.sourceDevices) { source in
                SourceDeviceRow(source: source, canSwitch: canSwitch) {
                    device.routeAudio(to: source.address)
                }
                if source.id != device.sourceDevices.last?.id { Divider() }
            }
        }
    }
}

private struct SourceDeviceRow: View {
    let source: SourceDevice
    let canSwitch: Bool
    let switchTo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: source.isRequestingHost ? "laptopcomputer" : "dot.radiowaves.left.and.right")
                .foregroundStyle(source.isConnected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name.isEmpty ? source.address.description : source.name)
                    .foregroundStyle(source.isConnected ? .primary : .secondary)
                HStack(spacing: 4) {
                    if source.isRequestingHost { SourceTag(text: .deviceThisMac) }
                    if source.isActiveSource { SourceTag(text: .deviceActiveSource, prominent: true) }
                    if !source.isActiveSource {
                        Text(source.isConnected ? .connectionConnected : .deviceNotConnected)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 8)
            if canSwitch && source.isConnected && !source.isActiveSource {
                Button(.deviceSwitchToDevice, action: switchTo)
                    .controlSize(.small)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SourceTag: View {
    let text: LocalizedStringResource
    var prominent = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .background(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .capsule)
    }
}

#Preview("Source devices") {
    let address = { (last: UInt8) in BluetoothAddress(bytes: [0xbc, 0xd0, 0x74, 0x72, 0x78, last])! }
    VStack(spacing: 12) {
        SourceDeviceRow(source: SourceDevice(address: address(1), name: "lemon", isConnected: true,
                                             isRequestingHost: false, isActiveSource: true),
                        canSwitch: true) {}
        Divider()
        SourceDeviceRow(source: SourceDevice(address: address(2), name: "juicer", isConnected: true,
                                             isRequestingHost: true, isActiveSource: false),
                        canSwitch: true) {}
        Divider()
        SourceDeviceRow(source: SourceDevice(address: address(3), name: "mixer", isConnected: false,
                                             isRequestingHost: false, isActiveSource: false),
                        canSwitch: true) {}
    }
    .padding(20)
    .frame(width: 400)
}
