struct NotificationBlocks: Equatable, CustomStringConvertible {
    static let validBlocks: ClosedRange<UInt8> = 0...31
    private static let bitmapLength = 4
    private static let enableMask: UInt8 = 0x01

    let blocks: Set<UInt8>

    init(blocks: Set<UInt8>) throws(ProbeError) {
        guard blocks.allSatisfy(Self.validBlocks.contains) else {
            throw .usage("Function blocks must be within \(Self.validBlocks.lowerBound)...\(Self.validBlocks.upperBound).")
        }
        self.blocks = blocks
    }

    init(list: String) throws(ProbeError) {
        guard list != "none" else {
            try self.init(blocks: [])
            return
        }
        var blocks: Set<UInt8> = []
        for item in list.split(separator: ",", omittingEmptySubsequences: false) {
            guard let block = UInt8(item) else {
                throw .usage("'\(item)' is not a function block number.")
            }
            blocks.insert(block)
        }
        try self.init(blocks: blocks)
    }

    init(bitmap: [UInt8]) throws(ProbeError) {
        guard bitmap.count == Self.bitmapLength else { throw .malformedNotificationState(bitmap) }
        let mask = bitmap.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        try self.init(blocks: Set(Self.validBlocks.filter { mask & (1 << UInt32($0)) != 0 }))
    }

    var bitmap: [UInt8] {
        let mask = blocks.reduce(UInt32(0)) { $0 | 1 << UInt32($1) }
        return (0..<Self.bitmapLength).reversed().map { UInt8(truncatingIfNeeded: mask >> (8 * UInt32($0))) }
    }

    var subscriptionPayload: [UInt8] { [Self.enableMask] + bitmap }

    var description: String {
        blocks.isEmpty ? "none" : blocks.sorted().map(String.init).joined(separator: ",")
    }
}
