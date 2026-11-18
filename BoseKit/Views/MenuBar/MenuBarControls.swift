import SwiftUI
import BoseKitEngine
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
                Button(L10n.Common.settings, systemImage: "gearshape") {
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
                Text(L10n.Connection.emptyTitle).font(.headline)
                Text(L10n.Connection.emptyHelp).foregroundStyle(.secondary)
                OpenBluetoothSettingsButton()
            }
        }
    }
}

private struct QuickDeviceControls: View {
    let device: DeviceController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = device.errorMessage {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            switch device.connection {
            case .connected:
                CompactSoundControls(device: device)
                    .disabled(device.busy)
            case .connecting:
                HStack {
                    ProgressView().controlSize(.small)
                    Text(L10n.Connection.connecting).foregroundStyle(.secondary)
                }
            case .disconnected:
                HStack {
                    Text(L10n.Connection.disconnected).foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.Connection.connect) { Task { await device.connect() } }
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
                    Text(L10n.Sound.equalizer)
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
                Text(L10n.Device.batteryPercentage(batteryPercentage))
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(L10n.Common.appName)
    }
}

#Preview("Menu Bar") {
    MenuBarControls(model: BoseAppModel())
}
