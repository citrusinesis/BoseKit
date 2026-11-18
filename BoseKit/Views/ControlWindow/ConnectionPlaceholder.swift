import SwiftUI
import BoseKitEngine

struct ConnectionPlaceholder: View {
    var device: DeviceController?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "headphones")
        } description: {
            Text(device == nil ? L10n.Connection.emptyHelp : L10n.Connection.help)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            if let device {
                Button(L10n.Connection.connect) { Task { await device.connect() } }
                    .buttonStyle(.glassProminent)
                    .disabled(device.connecting)
            } else {
                OpenBluetoothSettingsButton()
                    .buttonStyle(.glassProminent)
            }
        }
        .controlSize(.regular)
        .frame(maxWidth: .infinity, minHeight: 300)
        .accessibilityIdentifier(device == nil ? "noDevices" : "deviceDisconnected")
    }

    private var title: LocalizedStringResource {
        guard let device else { return L10n.Connection.emptyTitle }
        return device.connecting ? L10n.Connection.connecting : L10n.Connection.disconnected
    }
}

#Preview("Connection — English") {
    ConnectionPlaceholder()
        .padding(20)
        .frame(width: 420, height: 440)
        .environment(\.locale, Locale(identifier: "en"))
}

#Preview("Connection — Korean") {
    ConnectionPlaceholder()
        .padding(20)
        .frame(width: 420, height: 440)
        .environment(\.locale, Locale(identifier: "ko"))
}
