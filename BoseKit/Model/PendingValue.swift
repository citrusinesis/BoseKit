nonisolated struct PendingValue<Value> {
    struct Request {
        fileprivate let serial: Int
    }

    private(set) var value: Value?
    private var latestSerial = 0

    var isPending: Bool { value != nil }

    func shown(over confirmed: Value) -> Value { value ?? confirmed }

    mutating func request(_ newValue: Value) -> Request {
        latestSerial += 1
        value = newValue
        return Request(serial: latestSerial)
    }

    mutating func settle(_ request: Request) {
        if request.serial == latestSerial { value = nil }
    }

    mutating func clear() { value = nil }
}

nonisolated struct PendingTable<Key: Hashable, Value> {
    private var entries: [Key: PendingValue<Value>] = [:]

    subscript(key: Key) -> PendingValue<Value> {
        get { entries[key] ?? PendingValue() }
        set { entries[key] = newValue }
    }

    var isPending: Bool { entries.values.contains { $0.isPending } }

    mutating func clear() {
        for key in entries.keys { entries[key]?.clear() }
    }
}
