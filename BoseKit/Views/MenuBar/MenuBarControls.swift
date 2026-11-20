import SwiftUI
import AppKit

struct MenuBarControls: View {
    @Bindable var model: BoseAppModel
    @Environment(\.openWindow) private var openWindow
    @State private var contentHeight: CGFloat = 140

    var body: some View {
        VStack(spacing: 0) {
            DeviceHeader(model: model)
            Divider()
            ScrollView {
                MenuBarContent(device: model.selected)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .frame(height: min(contentHeight, 380))
            Divider()
            HStack {
                Button(.commonSettings, systemImage: "gearshape") {
                    openWindow(id: ControlWindow.id)
                    NSApp.activate()
                }
                .accessibilityIdentifier("openSettings")
                Spacer()
                AppActionsMenu(model: model)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 340)
        .buttonStyle(.glass)
    }
}

private struct MenuBarContent: View {
    let device: DeviceController?

    var body: some View {
        if let device {
            QuickDeviceControls(device: device).id(device.id)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(.connectionEmptyTitle).font(.headline)
                Text(.connectionEmptyHelp).foregroundStyle(.secondary)
                OpenBluetoothSettingsButton()
            }
        }
    }
}

private struct QuickDeviceControls: View {
    let device: DeviceController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = device.error {
                Label(error.message, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            switch device.connection {
            case .connected:
                CompactSoundControls(device: device)
            case .connecting:
                HStack {
                    ProgressView().controlSize(.small)
                    Text(.connectionConnecting).foregroundStyle(.secondary)
                }
            case .disconnected:
                HStack {
                    Text(.connectionDisconnected).foregroundStyle(.secondary)
                    Spacer()
                    Button(.connectionConnect) { Task { await device.connect() } }
                }
            }
        }
        .tracksDeviceVisibility(device)
    }
}

private struct CompactSoundControls: View {
    let device: DeviceController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ListeningControls(device: device, compact: true)
            if !device.equalizer.isEmpty {
                Divider()
                DisclosureGroup {
                    EqualizerControls(device: device).padding(.top, 8)
                } label: {
                    Text(.soundEqualizer)
                }
            }
        }
    }
}

struct MenuBarLabel: View {
    let batteryPercentage: UInt8?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "headphones")
            if let batteryPercentage {
                Text(.deviceBatteryPercentage(UInt32(batteryPercentage)))
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(.commonAppName)
    }
}

#Preview("Menu Bar") {
    MenuBarControls(model: BoseAppModel())
}
