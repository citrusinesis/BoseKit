import BoseKitEngine
import Testing
@testable import BoseKitProbe

struct SnapshotOptionsTests {
    @Test func defaultSetIsUniqueAndLeavesOutRiskyOrArgumentTakingRegisters() throws {
        let registers = SnapshotOptions.defaultRegisters
        #expect(Set(registers).count == registers.count)
        #expect(!registers.contains { [3, 7, 8, 18].contains($0.block) })
        #expect(!registers.contains(BMAPAddress(0, 12)))
        #expect(!registers.contains(.deviceInfo))
        #expect(!registers.contains(.modeList))
        #expect(!registers.contains(.modeConfiguration))
        #expect(try SnapshotOptions(registerList: nil, skipList: nil).registers == registers)
    }

    @Test func defaultSetCoversTheKnownReadableRegisters() {
        let expected: [BMAPAddress] = [
            .firmware, .battery, .notifications, .currentMode, .audioSettings, BMAPAddress(1, 4), BMAPAddress(1, 16),
            BMAPAddress(2, 3), BMAPAddress(2, 5), BMAPAddress(2, 9), BMAPAddress(2, 12), BMAPAddress(5, 4),
            BMAPAddress(4, 9), BMAPAddress(31, 10),
        ]
        #expect(expected.allSatisfy(SnapshotOptions.defaultRegisters.contains))
    }

    @Test func registerListReplacesTheDefaultsInTheGivenOrder() throws {
        let options = try SnapshotOptions(registerList: "2.9,2.5,31.10", skipList: nil)
        #expect(options.registers == [BMAPAddress(2, 9), BMAPAddress(2, 5), BMAPAddress(31, 10)])
    }

    @Test func skipListRemovesRegisters() throws {
        let options = try SnapshotOptions(registerList: nil, skipList: "2.2,9.2")
        #expect(!options.registers.contains(.battery))
        #expect(!options.registers.contains(.notifications))
        #expect(options.registers.count == SnapshotOptions.defaultRegisters.count - 2)
    }

    @Test(arguments: ["", "2", "2.", ".5", "2.5.1", "a.b", "256.1", "2.5,", "2.5, 2.9", "-1.2"])
    func malformedRegisterListsAreRejected(_ list: String) {
        #expect(throws: ProbeError.self) { try SnapshotOptions(registerList: list, skipList: nil) }
    }

    @Test func duplicatesUnknownSkipsAndEmptySetsAreRejected() {
        #expect(throws: ProbeError.self) { try SnapshotOptions(registerList: "2.5,2.5", skipList: nil) }
        #expect(throws: ProbeError.self) { try SnapshotOptions(registerList: "2.5", skipList: "2.9") }
        #expect(throws: ProbeError.self) { try SnapshotOptions(registerList: "2.5", skipList: "2.5") }
    }
}
