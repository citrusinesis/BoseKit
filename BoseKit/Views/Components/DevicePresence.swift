import SwiftUI
import AppKit

extension View {
    func tracksDeviceVisibility(_ device: DeviceController) -> some View {
        onAppear {
            device.attachView()
            Task { await device.refresh() }
        }
        .onDisappear { device.detachView() }
    }
}

struct OpenBluetoothSettingsButton: View {
    var body: some View {
        Button(.connectionOpenBluetoothSettings) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
