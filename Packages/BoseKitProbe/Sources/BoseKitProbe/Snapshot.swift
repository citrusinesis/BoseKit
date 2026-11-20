import BoseKitEngine

enum RegisterReply: Equatable {
    case answered([UInt8])
    case deviceError([UInt8])
}

enum RegisterReading: Equatable {
    case replied(RegisterReply)
    case unresponsive
}

struct Snapshot: Equatable {
    struct Entry: Equatable {
        let address: BMAPAddress
        let reading: RegisterReading
    }

    struct Change: Equatable {
        let address: BMAPAddress
        let old: RegisterReading?
        let new: RegisterReading
    }

    let entries: [Entry]

    func changes(since previous: Snapshot) -> [Change] {
        let old = Dictionary(uniqueKeysWithValues: previous.entries.map { ($0.address, $0.reading) })
        return entries.compactMap { entry in
            old[entry.address] == entry.reading
                ? nil
                : Change(address: entry.address, old: old[entry.address], new: entry.reading)
        }
    }
}
