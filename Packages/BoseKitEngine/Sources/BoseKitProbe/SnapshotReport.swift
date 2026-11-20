import BoseKitEngine
import Foundation

enum SnapshotReport {
    private static let indent = "    "

    static func lines(number: Int, label: String, time: String, snapshot: Snapshot, previous: Snapshot?) -> [String] {
        let header = "== \(time)  snapshot \(number)" + (label.isEmpty ? "" : ": \(label)")
        guard let previous else { return [header] + inventory(snapshot) }
        let changes = snapshot.changes(since: previous)
        guard !changes.isEmpty else { return [header, indent + "no changes"] }
        return [header] + changes.map { change in
            row(change.address, "\(describe(change.old)) → \(describe(change.new))")
        }
    }

    static func unresponsiveNotice(_ address: BMAPAddress, time: String, timeout: Duration) -> String {
        let limit = timeout.formatted(.units(allowed: [.seconds, .milliseconds], width: .abbreviated))
        return "\(time)  \(RegisterCatalog.column(for: address))  no answer within \(limit); "
            + "reconnecting and skipping this register for the rest of the run"
    }

    private static func inventory(_ snapshot: Snapshot) -> [String] {
        var answered = 0
        var rejected = 0
        var unresponsive = 0
        var rows: [String] = []
        for entry in snapshot.entries {
            switch entry.reading {
            case .replied(.answered): answered += 1
            case .replied(.deviceError): rejected += 1
            case .unresponsive:
                unresponsive += 1
                continue
            }
            rows.append(row(entry.address, describe(entry.reading)))
        }
        return rows + [indent + "\(answered) answered, \(rejected) device errors, \(unresponsive) unresponsive"]
    }

    private static func row(_ address: BMAPAddress, _ value: String) -> String {
        indent + RegisterCatalog.column(for: address) + "  " + value
    }

    private static func describe(_ reading: RegisterReading?) -> String {
        switch reading {
        case nil: "not read"
        case .unresponsive: "no answer"
        case .replied(.answered(let payload)): payload.isEmpty ? "(empty)" : EventLine.hex(payload)
        case .replied(.deviceError(let payload)): payload.isEmpty ? "ERROR" : "ERROR \(EventLine.errorPayload(payload))"
        }
    }
}
