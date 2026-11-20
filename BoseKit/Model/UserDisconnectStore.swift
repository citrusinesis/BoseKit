import Foundation

struct UserDisconnectStore {
    private static let key = "userDisconnectedDeviceIDs"

    let defaults: UserDefaults

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    func set(_ disconnected: Bool, for id: String) {
        var updated = ids
        if disconnected { updated.insert(id) } else { updated.remove(id) }
        store(updated)
    }

    func keepOnly(_ pairedIDs: Set<String>) {
        store(ids.intersection(pairedIDs))
    }

    private func store(_ updated: Set<String>) {
        guard updated != ids else { return }
        if updated.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(updated.sorted(), forKey: Self.key)
        }
    }

    private var ids: Set<String> {
        Set(defaults.stringArray(forKey: Self.key) ?? [])
    }
}
