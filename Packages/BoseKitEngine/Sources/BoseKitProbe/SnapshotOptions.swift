import BoseKitEngine

struct SnapshotOptions: Equatable {
    static let requestTimeout: Duration = .seconds(2)

    static let defaultRegisters: [BMAPAddress] = [
        (0, [0, 1, 2, 3, 5, 6, 7, 15, 17, 23]),
        (1, [0, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 20, 24, 27, 29]),
        (2, [0, 2, 3, 5, 9, 12, 16, 21]),
        (4, [0, 1, 4, 8, 9, 14, 18]),
        (5, [0, 1, 3, 4, 5, 7, 13, 17]),
        (9, [0, 2]),
        (31, [0, 2, 3, 4, 8, 10, 11]),
    ].flatMap { (block: UInt8, functions: [UInt8]) in functions.map { BMAPAddress(block, $0) } }

    let registers: [BMAPAddress]

    init(registers: [BMAPAddress]) throws(ProbeError) {
        guard !registers.isEmpty else { throw .usage("The snapshot register list is empty.") }
        var seen: Set<BMAPAddress> = []
        for register in registers where !seen.insert(register).inserted {
            throw .usage("Register \(register.block).\(register.function) is listed twice.")
        }
        self.registers = registers
    }

    init(registerList: String?, skipList: String?) throws(ProbeError) {
        let registers = try registerList.map(Self.addresses) ?? Self.defaultRegisters
        let skipped = try skipList.map(Self.addresses) ?? []
        for register in skipped where !registers.contains(register) {
            throw .usage("Register \(register.block).\(register.function) is not in the snapshot set.")
        }
        try self.init(registers: registers.filter { !skipped.contains($0) })
    }

    static func addresses(in list: String) throws(ProbeError) -> [BMAPAddress] {
        try list.split(separator: ",", omittingEmptySubsequences: false).map { (item) throws(ProbeError) in
            let parts = item.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 2, let block = UInt8(parts[0]), let function = UInt8(parts[1]) else {
                throw .usage("'\(item)' is not a register; write it as <block>.<function>, for example 2.5.")
            }
            return BMAPAddress(block, function)
        }
    }
}
