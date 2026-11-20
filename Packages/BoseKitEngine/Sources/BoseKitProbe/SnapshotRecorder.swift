import BoseKitEngine

@MainActor
struct SnapshotRecorder {
    private let registers: [BMAPAddress]
    private var unresponsive: Set<BMAPAddress> = []
    private var previous: Snapshot?
    private var count = 0

    init(_ options: SnapshotOptions) {
        registers = options.registers
    }

    mutating func take(label: String, on probe: ProbeSession) async throws {
        let time = Timestamp.now()
        var entries: [Snapshot.Entry] = []
        for address in registers {
            entries.append(Snapshot.Entry(address: address, reading: try await reading(of: address, on: probe)))
        }
        count += 1
        let snapshot = Snapshot(entries: entries)
        for line in SnapshotReport.lines(number: count, label: label, time: time, snapshot: snapshot,
                                         previous: previous) {
            print(line)
        }
        previous = snapshot
    }

    private mutating func reading(of address: BMAPAddress, on probe: ProbeSession) async throws -> RegisterReading {
        guard !unresponsive.contains(address) else { return .unresponsive }
        do {
            return .replied(try await probe.read(address, timeout: SnapshotOptions.requestTimeout))
        } catch BoseError.timeout {
            try Task.checkCancellation()
            unresponsive.insert(address)
            print(SnapshotReport.unresponsiveNotice(address, time: Timestamp.now(),
                                                    timeout: SnapshotOptions.requestTimeout))
            do {
                try await probe.reconnect()
            } catch {
                try Task.checkCancellation()
                throw ProbeError.reconnectFailed(String(describing: error))
            }
            return .unresponsive
        } catch BoseError.disconnected {
            try Task.checkCancellation()
            throw ProbeError.connectionLost
        }
    }
}
