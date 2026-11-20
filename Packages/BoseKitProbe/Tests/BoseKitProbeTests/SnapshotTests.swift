import BoseKitEngine
import Testing
@testable import BoseKitProbe

struct SnapshotTests {
    private let aux = BMAPAddress(2, 3)
    private let charger = BMAPAddress(2, 5)

    private func snapshot(_ entries: [(BMAPAddress, RegisterReading)]) -> Snapshot {
        Snapshot(entries: entries.map { Snapshot.Entry(address: $0.0, reading: $0.1) })
    }

    @Test func identicalSnapshotsHaveNoChanges() {
        let readings = snapshot([(.battery, .replied(.answered([0x50]))), (aux, .unresponsive)])
        #expect(readings.changes(since: readings).isEmpty)
    }

    @Test func changesKeepRegisterOrderAndCoverEveryKindOfTransition() {
        let before = snapshot([
            (.battery, .replied(.answered([0x50, 0xff, 0xff, 0x00]))),
            (aux, .replied(.deviceError([0x04]))),
            (charger, .replied(.answered([0x00]))),
            (.notifications, .replied(.answered([0, 0, 0, 0]))),
        ])
        let after = snapshot([
            (.battery, .replied(.answered([0x4f, 0xff, 0xff, 0x00]))),
            (aux, .replied(.answered([0x01]))),
            (charger, .unresponsive),
            (.notifications, .replied(.answered([0, 0, 0, 0]))),
        ])
        #expect(after.changes(since: before) == [
            Snapshot.Change(address: .battery, old: .replied(.answered([0x50, 0xff, 0xff, 0x00])),
                            new: .replied(.answered([0x4f, 0xff, 0xff, 0x00]))),
            Snapshot.Change(address: aux, old: .replied(.deviceError([0x04])), new: .replied(.answered([0x01]))),
            Snapshot.Change(address: charger, old: .replied(.answered([0x00])), new: .unresponsive),
        ])
    }

    @Test func registerMissingFromThePreviousSnapshotCountsAsAChange() {
        let after = snapshot([(aux, .replied(.answered([0x01])))])
        #expect(after.changes(since: snapshot([])) == [
            Snapshot.Change(address: aux, old: nil, new: .replied(.answered([0x01]))),
        ])
    }
}
