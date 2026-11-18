import Foundation
@testable import BoseKitEngine

actor ModeSimulatorTransport: BMAPTransport {
    private let stream: AsyncThrowingStream<[UInt8], any Error>
    private let sink: AsyncThrowingStream<[UInt8], any Error>.Continuation
    private var slots: [[UInt8]]
    private var currentSlot: UInt8 = 3
    private let corruptReadBack: Bool
    private(set) var writes: [[UInt8]] = []

    init(corruptReadBack: Bool = false, currentModeName: [UInt8] = [88]) {
        self.corruptReadBack = corruptReadBack
        let pair = AsyncThrowingStream<[UInt8], any Error>.makeStream()
        stream = pair.stream
        sink = pair.continuation
        slots = (0..<10).map { index in
            var bytes = [UInt8](repeating: 0, count: 47)
            bytes[0] = UInt8(index)
            bytes[3] = index >= 3 ? 1 : 0
            bytes[4] = index == 3 ? 1 : 0
            let name = index == 3 ? currentModeName : [88]
            bytes.replaceSubrange(6..<(6 + name.count), with: name)
            bytes[42] = index == 3 ? 7 : 10
            return bytes
        }
    }

    func open() -> AsyncThrowingStream<[UInt8], any Error> { stream }
    func close() { sink.finish() }

    func write(_ bytes: [UInt8]) throws {
        writes.append(bytes)
        if bytes[0] == 31 && bytes[1] == 1 {
            var response: [UInt8] = [31, 1, 7, 0]
            for slot in slots { response += [31, 6, 3, 47] + slot }
            response += [31, 1, 6, 0]
            sink.yield(response)
        } else if bytes[0] == 31 && bytes[1] == 3 {
            if bytes[2] == 5 {
                currentSlot = bytes[4]
                sink.yield([31, 3, 7, 0, 31, 3, 6, 1, currentSlot])
            } else {
                sink.yield([31, 3, 3, 1, currentSlot])
            }
        } else if bytes[0] == 31 && bytes[1] == 6 && bytes[2] == 2 {
            let p = Array(bytes.dropFirst(4))
            guard p.count == 39, p[0] < 10 else { throw BoseError.invalidPayload("Mode write") }
            var status = slots[Int(p[0])]
            status[1] = p[1]; status[2] = p[2]
            status.replaceSubrange(6..<38, with: p[3..<35])
            status[42] = p[38] == 1 ? 0 : p[35]
            status[43] = p[36]; status[44] = p[37]; status[46] = p[38]
            status[4] = p[1] == 0 && p[2] == 0 && Array(p[3..<7]) == Array(ModeConfiguration.emptyName.rawValue.utf8) ? 0 : 1
            if corruptReadBack { status[42] = 9 }
            slots[Int(p[0])] = status
            sink.yield([31, 6, 3, 39] + p)
        } else {
            throw BoseError.invalidPayload("Unexpected command")
        }
    }
}
