import BoseKitEngine

struct ProbeTarget: Equatable {
    let address: String
    let name: String
    let profileID: String?
    let isConnected: Bool

    static func merging(_ devices: [PairedBluetoothDevice], registry: DeviceRegistry) -> [ProbeTarget] {
        var order: [String] = []
        var merged: [String: ProbeTarget] = [:]
        for device in devices where device.identity?.isBose == true {
            let key = device.id.lowercased()
            let entry = ProbeTarget(address: device.id, name: device.name,
                                    profileID: device.profile(in: registry)?.id, isConnected: device.isConnected)
            guard let existing = merged[key] else {
                order.append(key)
                merged[key] = entry
                continue
            }
            merged[key] = ProbeTarget(address: existing.address, name: existing.name,
                                      profileID: existing.profileID ?? entry.profileID,
                                      isConnected: existing.isConnected || entry.isConnected)
        }
        return order.compactMap { merged[$0] }
    }
}
