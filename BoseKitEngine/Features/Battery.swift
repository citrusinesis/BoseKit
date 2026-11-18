public struct BatteryComponent: RawRepresentable, Hashable, Sendable, Comparable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let right = Self(rawValue: 1)
    public static let left = Self(rawValue: 2)
    public static let chargingCase = Self(rawValue: 3)
    public static let overall = Self(rawValue: 4)

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum BatteryLayout: Sendable {
    case percentage
    case components(aggregate: BatteryComponent, fallback: Set<BatteryComponent>)
}

public struct BatteryStatus: Equatable, Sendable {
    public let percentage: UInt8?
    public let components: [BatteryComponent: UInt8]
}
