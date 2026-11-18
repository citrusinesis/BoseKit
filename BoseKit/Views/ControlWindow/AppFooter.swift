import SwiftUI
import BoseKitEngine
import AppKit

struct AppFooter: View {
    let model: BoseAppModel

    var body: some View {
        HStack {
            ConnectionStatus(device: model.selected)
            Spacer()
            AppActionsMenu(model: model)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct ConnectionStatus: View {
    let device: DeviceController?

    var body: some View {
        if device?.busy == true || device?.connecting == true {
            ProgressView().controlSize(.small)
            Text(.connectionUpdating).font(.caption)
        } else {
            let connected = device?.connected == true
            Circle()
                .fill(connected ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
            Text(connected ? .connectionConnected : .connectionWaiting)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct AppActionsMenu: View {
    let model: BoseAppModel

    var body: some View {
        Menu {
            Button(.menuRefresh, systemImage: "arrow.clockwise") {
                Task {
                    await model.discover()
                    await model.selected?.refresh()
                }
            }
            .disabled(model.selected?.busy == true || model.selected?.connecting == true)
            Divider()
            Button(.menuQuit) { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 20, height: 20)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(.commonApp)
        .help(.commonApp)
    }
}
