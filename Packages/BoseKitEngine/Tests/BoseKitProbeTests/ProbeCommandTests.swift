import BoseKitEngine
import Testing
@testable import BoseKitProbe

struct ProbeCommandTests {
    @Test(arguments: [[], ["help"], ["--help"], ["-h"]] as [[String]])
    func helpIsTheDefault(_ arguments: [String]) throws {
        #expect(try ProbeCommand(arguments: arguments) == .help)
    }

    @Test func listTakesNoOptions() throws {
        #expect(try ProbeCommand(arguments: ["list"]) == .list)
        #expect(throws: ProbeError.self) { try ProbeCommand(arguments: ["list", "--address"]) }
    }

    @Test func monitorWithoutOptionsWritesNothing() throws {
        #expect(try ProbeCommand(arguments: ["monitor"]) == .monitor(MonitorOptions()))
    }

    @Test func monitorParsesAddressAndSubscription() throws {
        let command = try ProbeCommand(arguments: ["monitor", "--subscribe", "1,31", "--address", "AC:BF:71:0A:1B:2C"])
        let expected = MonitorOptions(address: BluetoothAddress(string: "ac-bf-71-0a-1b-2c"),
                                      subscription: try NotificationBlocks(blocks: [1, 31]))
        #expect(command == .monitor(expected))
    }

    @Test func snapshotsFlagTakesNoValueAndUsesTheDefaultSet() throws {
        let command = try ProbeCommand(arguments: ["monitor", "--snapshots", "--subscribe", "2"])
        let expected = MonitorOptions(subscription: try NotificationBlocks(blocks: [2]),
                                      snapshots: try SnapshotOptions(registers: SnapshotOptions.defaultRegisters))
        #expect(command == .monitor(expected))
    }

    @Test func snapshotRegisterOptionsShapeTheSet() throws {
        let command = try ProbeCommand(arguments: [
            "monitor", "--snapshot-registers", "2.5,2.9,2.2", "--snapshots", "--skip-registers", "2.2",
        ])
        let expected = MonitorOptions(snapshots: try SnapshotOptions(registers: [BMAPAddress(2, 5), BMAPAddress(2, 9)]))
        #expect(command == .monitor(expected))
    }

    @Test(arguments: [
        ["monitor", "--snapshot-registers", "2.5"], ["monitor", "--skip-registers", "2.2"],
        ["monitor", "--snapshots", "--snapshot-registers"], ["monitor", "--snapshots", "--skip-registers", "99.99"],
    ] as [[String]])
    func snapshotRegisterOptionsNeedSnapshotsAndValidLists(_ arguments: [String]) {
        #expect(throws: ProbeError.self) { try ProbeCommand(arguments: arguments) }
    }

    @Test(arguments: [
        ["scan"], ["monitor", "--address"], ["monitor", "--address", "nope"],
        ["monitor", "--subscribe", "99"], ["monitor", "--verbose", "1"],
    ] as [[String]])
    func malformedInvocationsAreUsageErrors(_ arguments: [String]) {
        #expect(throws: ProbeError.self) { try ProbeCommand(arguments: arguments) }
    }
}
