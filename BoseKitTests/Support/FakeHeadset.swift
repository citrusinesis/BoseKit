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
    private var rejected: [BMAPAddress: [BMAPOperator: BMAPErrorCode?]] = [:]
    private var rejectedSlots: Set<UInt8> = []
    private var dropsLink: Set<BMAPAddress> = []
    private var stored: [BMAPAddress: [UInt8]] = [:]
    private var modeTable = FakeModeTable(.presets)
    private var pendingHold: Hold?
    private var heldRequest: [UInt8]?
    private var holdWaiter: CheckedContinuation<Void, Never>?

    func open() -> AsyncThrowingStream<[UInt8], any Error> { pair.stream }

    func close() {
        closes += 1
        pair.continuation.finish()
    }

    func reject(_ address: BMAPAddress, _ operation: BMAPOperator, code: BMAPErrorCode? = .operatorNotSupported) {
        rejected[address, default: [:]][operation] = .some(code)
    }
    func accept(_ address: BMAPAddress) { rejected[address] = nil }
    func rejectSelection(of slot: UInt8) { rejectedSlots.insert(slot) }
    func dropLink(on address: BMAPAddress) { dropsLink.insert(address) }
    func store(_ payload: [UInt8], at address: BMAPAddress) { stored[address] = payload }
    func useModes(_ table: FakeModeTable) { modeTable = table }
    func setCurrentMode(_ slot: UInt8) { currentMode = slot }

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

    func requests(after count: Int) -> [FakeRequest] {
        requests.dropFirst(count).map { FakeRequest(BMAPAddress($0[0], $0[1]), BMAPOperator(rawValue: $0[2])) }
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
        if let operation, let code = rejected[address]?[operation] {
            let payload = code.map { [$0.rawValue] } ?? []
            pair.continuation.yield([bytes[0], bytes[1], BMAPOperator.error.rawValue, UInt8(payload.count)] + payload)
            return
        }
        if let value = stored[address] {
            let payload = operation == .setGet ? Array(bytes.dropFirst(4)) : value
            stored[address] = payload
            pair.continuation.yield([bytes[0], bytes[1], BMAPOperator.status.rawValue, UInt8(payload.count)] + payload)
            return
        }
        switch (address, operation) {
        case (.modeList, .start?):
            pair.continuation.yield(modeTable.listResponse)
        case (.modeConfiguration, .setGet?):
            guard let response = modeTable.write(Array(bytes.dropFirst(4))) else {
                pair.continuation.yield([bytes[0], bytes[1], BMAPOperator.error.rawValue, 1,
                                         BMAPErrorCode.invalidData.rawValue])
                return
            }
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
        case (.deviceList, _):
            pair.continuation.yield([4, 4, BMAPOperator.status.rawValue, 7, 0] + Self.sourceAddress)
        case (.deviceInfo, _):
            let info = Self.sourceAddress + [1, 0, 0] + Array("Mac".utf8)
            pair.continuation.yield([4, 5, BMAPOperator.status.rawValue, UInt8(info.count)] + info)
        case (.anr, _):
            pair.continuation.yield([bytes[0], bytes[1], BMAPOperator.status.rawValue, 1, ANRLevel.high.rawValue])
        default:
            pair.continuation.yield([bytes[0], bytes[1], BMAPOperator.status.rawValue, 1, 90])
        }
    }

    static let sourceAddress: [UInt8] = [1, 2, 3, 4, 5, 6]
}

struct FakeRequest: Equatable, CustomStringConvertible {
    let address: BMAPAddress
    let operation: BMAPOperator?

    init(_ address: BMAPAddress, _ operation: BMAPOperator?) {
        self.address = address
        self.operation = operation
    }

    var description: String {
        "\(address.block).\(address.function) \(operation.map { "\($0)" } ?? "?")"
    }
}
