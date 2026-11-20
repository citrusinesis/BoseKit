import BoseKitEngine
import Testing
@testable import BoseKitProbe

struct SnapshotReportTests {
    private let aux = BMAPAddress(2, 3)

    private func snapshot(_ entries: [(BMAPAddress, RegisterReading)]) -> Snapshot {
        Snapshot(entries: entries.map { Snapshot.Entry(address: $0.0, reading: $0.1) })
    }

    private func row(_ address: BMAPAddress, _ value: String) -> String {
        "    " + RegisterCatalog.column(for: address) + "  " + value
    }

    @Test func firstSnapshotListsRepliesAndErrorsButNotUnresponsiveRegisters() {
        let first = snapshot([
            (.battery, .replied(.answered([0x50, 0xff, 0xff, 0x00]))),
            (aux, .replied(.deviceError([0x04]))),
            (.anr, .unresponsive),
            (.notifications, .replied(.answered([]))),
            (BMAPAddress(1, 4), .replied(.deviceError([]))),
        ])
        let lines = SnapshotReport.lines(number: 1, label: "before play", time: "12:00:00.000",
                                         snapshot: first, previous: nil)
        #expect(lines == [
            "== 12:00:00.000  snapshot 1: before play",
            row(.battery, "50 ff ff 00"),
            row(aux, "ERROR 04 (FuncNotSupp)"),
            row(.notifications, "(empty)"),
            row(BMAPAddress(1, 4), "ERROR"),
            "    2 answered, 2 device errors, 1 unresponsive",
        ])
    }

    @Test func laterSnapshotsShowOnlyChangedRegisters() {
        let before = snapshot([(.battery, .replied(.answered([0x50]))), (aux, .replied(.deviceError([0x04])))])
        let after = snapshot([(.battery, .replied(.answered([0x50]))), (aux, .replied(.answered([0x01])))])
        let lines = SnapshotReport.lines(number: 2, label: "after cable in", time: "t", snapshot: after,
                                         previous: before)
        #expect(lines == ["== t  snapshot 2: after cable in", row(aux, "ERROR 04 (FuncNotSupp) → 01")])
    }

    @Test func registerThatStopsAnsweringIsShownAsNoAnswer() {
        let before = snapshot([(aux, .replied(.answered([0x00])))])
        let after = snapshot([(aux, .unresponsive)])
        let lines = SnapshotReport.lines(number: 3, label: "x", time: "t", snapshot: after, previous: before)
        #expect(lines.last == row(aux, "00 → no answer"))
    }

    @Test func unchangedSnapshotSaysSoAndAnEmptyLabelIsLeftOut() {
        let readings = snapshot([(.battery, .replied(.answered([0x50])))])
        let lines = SnapshotReport.lines(number: 2, label: "", time: "t", snapshot: readings, previous: readings)
        #expect(lines == ["== t  snapshot 2", "    no changes"])
    }

    @Test func unresponsiveNoticeNamesTheRegisterAndTheTimeout() {
        let notice = SnapshotReport.unresponsiveNotice(.anr, time: "t", timeout: .seconds(2))
        #expect(notice.hasPrefix("t  " + RegisterCatalog.column(for: .anr) + "  no answer within 2"))
        #expect(notice.hasSuffix("reconnecting and skipping this register for the rest of the run"))
    }
}
