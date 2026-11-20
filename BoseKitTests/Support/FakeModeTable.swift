import BoseKitEngine

struct FakeModeTable {
    enum Layout {
        case presets, editable
    }

    static let slots: [UInt8] = [0, 1, 2, 3]
    static let editableSlots: Set<UInt8> = [2, 3]
    static let configuredCNC: UInt8 = 7

    private static let maximumCNC: UInt8 = 10
    private static let writeLength = 39

    let layout: Layout
    private var statuses: [UInt8: [UInt8]]

    init(_ layout: Layout) {
        self.layout = layout
        statuses = Dictionary(uniqueKeysWithValues: Self.slots.map { ($0, Self.initialStatus($0, layout)) })
    }

    var statusLength: Int {
        switch layout {
        case .presets: 44
        case .editable: 47
        }
    }

    var listResponse: [UInt8] {
        var response: [UInt8] = [31, 1, BMAPOperator.processing.rawValue, 0]
        for slot in Self.slots {
            response += [31, 6, BMAPOperator.status.rawValue, UInt8(statusLength)] + (statuses[slot] ?? [])
        }
        return response + [31, 1, BMAPOperator.result.rawValue, 0]
    }

    mutating func write(_ payload: [UInt8]) -> [UInt8]? {
        guard layout == .editable, payload.count == Self.writeLength, var status = statuses[payload[0]] else {
            return nil
        }
        let windBlock = payload[38]
        status[1] = payload[1]
        status[2] = payload[2]
        status[4] = 1
        status.replaceSubrange(6..<38, with: payload[3..<35])
        status[42] = windBlock == 1 ? 0 : payload[35]
        status[43] = payload[36]
        status[44] = payload[37]
        status[46] = windBlock
        statuses[payload[0]] = status
        return [31, 6, BMAPOperator.status.rawValue, UInt8(payload.count)] + payload
    }

    private static func initialStatus(_ slot: UInt8, _ layout: Layout) -> [UInt8] {
        switch layout {
        case .presets:
            var bytes = [UInt8](repeating: 0, count: 44)
            bytes[0] = slot
            bytes[4] = 1
            return bytes
        case .editable:
            var bytes = [UInt8](repeating: 0, count: 47)
            bytes[0] = slot
            bytes[3] = editableSlots.contains(slot) ? 1 : 0
            bytes[4] = slot == 3 ? 0 : 1
            bytes[6] = UInt8(ascii: "X")
            bytes[42] = slot == 2 ? configuredCNC : maximumCNC
            return bytes
        }
    }
}
