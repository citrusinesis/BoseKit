import SwiftUI

struct ConnectionPlaceholder: View {
    var device: DeviceController?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "headphones")
        } description: {
            Text(device == nil ? .connectionEmptyHelp : .connectionHelp)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            if let device {
                Button(.connectionConnect) { Task { await device.connect() } }
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
        guard let device else { return .connectionEmptyTitle }
        return device.connecting ? .connectionConnecting : .connectionDisconnected
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
