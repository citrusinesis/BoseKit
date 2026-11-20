extension BoseAppModel {
    func selectAfterConnecting(_ device: DeviceController) {
        guard selected?.connected != true else { return }
        selectedID = device.id
    }

    func selectAfterLosing(_ device: DeviceController) {
        guard device.id == selected?.id, let connected = devices.first(where: \.connected) else { return }
        selectedID = connected.id
    }

    func reconcileSelection() {
        guard !devices.contains(where: { $0.id == selectedID }),
              let fallback = devices.first(where: \.connected) ?? devices.first else { return }
        selectedID = fallback.id
    }
}
