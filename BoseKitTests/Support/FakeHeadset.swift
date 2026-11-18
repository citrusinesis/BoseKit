import BoseKitEngine

actor FakeHeadset: BMAPTransport {
    private struct Hold {
        let address: BMAPAddress
        let operation: BMAPOperator
    }

    private let pair = AsyncThrowingStream<[UInt8], any Error>.makeStream()
    private(set) var closes = 0
    private(set) var requests: [[UInt8]] = []
    private(set) var currentMode: UInt8 = 0
    private var rejected: [BMAPAddress: Set<BMAPOperator>] = [:]
    private var rejectedSlots: Set<UInt8> = []
    private var dropsLink: Set<BMAPAddress> = []
    private var pendingHold: Hold?
    private var heldRequest: [UInt8]?
    private var holdWaiter: CheckedContinuation<Void, Never>?

    func open() -> AsyncThrowingStream<[UInt8], any Error> { pair.stream }

    func close() {
        closes += 1
        pair.continuation.finish()
    }

    func reject(_ address: BMAPAddress, _ operation: BMAPOperator) { rejected[address, default: []].insert(operation) }
    func accept(_ address: BMAPAddress) { rejected[address] = nil }
    func rejectSelection(of slot: UInt8) { rejectedSlots.insert(slot) }
    func dropLink(on address: BMAPAddress) { dropsLink.insert(address) }

    func holdNext(_ address: BMAPAddress, _ operation: BMAPOperator) {
        pendingHold = Hold(address: address, operation: operation)
    }

    func waitUntilHeld() async {
        guard heldRequest == nil else { return }
        await withCheckedContinuation { holdWaiter = $0 }
    }

    func release() {
        guard let request = heldRequest else { return }
        heldRequest = nil
        respond(to: request)
    }

    func requestCount(_ address: BMAPAddress) -> Int {
        requests.count(where: { $0[0] == address.block && $0[1] == address.function })
    }

    func write(_ bytes: [UInt8]) {
        requests.append(bytes)
        let address = BMAPAddress(bytes[0], bytes[1])
        if let hold = pendingHold, hold.address == address, hold.operation.rawValue == bytes[2] {
            pendingHold = nil
            heldRequest = bytes
            holdWaiter?.resume()
            holdWaiter = nil
            return
        }
        respond(to: bytes)
    }

    private func respond(to bytes: [UInt8]) {
        let address = BMAPAddress(bytes[0], bytes[1])
        let operation = BMAPOperator(rawValue: bytes[2])
        if dropsLink.contains(address) {
            pair.continuation.finish()
            return
        }
        if let operation, rejected[address]?.contains(operation) == true {
            pair.continuation.yield([bytes[0], bytes[1], BMAPOperator.error.rawValue, 1, 5])
            return
        }
        switch (address, operation) {
        case (.modeList, .start?):
            var response: [UInt8] = [31, 1, BMAPOperator.processing.rawValue, 0]
            for slot in Self.modeSlots { response += [31, 6, BMAPOperator.status.rawValue, 44] + Self.modeStatus(slot) }
            response += [31, 1, BMAPOperator.result.rawValue, 0]
            pair.continuation.yield(response)
        case (.currentMode, .start?):
            let slot = bytes[4]
            if rejectedSlots.contains(slot) {
                pair.continuation.yield([31, 3, BMAPOperator.error.rawValue, 1, 5])
                return
            }
            currentMode = slot
            pair.continuation.yield([31, 3, BMAPOperator.processing.rawValue, 0,
                                     31, 3, BMAPOperator.result.rawValue, 1, slot])
        case (.currentMode, _):
            pair.continuation.yield([31, 3, BMAPOperator.status.rawValue, 1, currentMode])
        case (_, .start?):
            pair.continuation.yield([bytes[0], bytes[1], BMAPOperator.result.rawValue, 0])
        case (.anr, _):
            pair.continuation.yield([bytes[0], bytes[1], BMAPOperator.status.rawValue, 1, ANRLevel.high.rawValue])
        default:
            pair.continuation.yield([bytes[0], bytes[1], BMAPOperator.status.rawValue, 1, 90])
        }
    }

    static let modeSlots: [UInt8] = [0, 1, 2, 3]

    private static func modeStatus(_ slot: UInt8) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 44)
        bytes[0] = slot
        bytes[4] = 1
        return bytes
    }
}
