public struct CNCLevel: RawRepresentable, Hashable, Comparable, Sendable, ExpressibleByIntegerLiteral {
    public static let range: ClosedRange<UInt8> = 0...10
    public static let minimum = CNCLevel(integerLiteral: range.lowerBound)
    public static let maximum = CNCLevel(integerLiteral: range.upperBound)

    public let rawValue: UInt8

    public init?(rawValue: UInt8) {
        guard Self.range.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(integerLiteral value: UInt8) {
        guard let level = Self(rawValue: value) else { preconditionFailure("CNC level must be \(Self.range)") }
        self = level
    }

    init(decoding rawValue: UInt8) throws {
        guard let level = Self(rawValue: rawValue) else {
            throw BoseError.invalidPayload("CNC level \(rawValue) is outside \(Self.range)")
        }
        self = level
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
