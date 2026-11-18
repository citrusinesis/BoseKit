public struct RFCOMMChannel: RawRepresentable, Hashable, Sendable, ExpressibleByIntegerLiteral {
    public static let range: ClosedRange<UInt8> = 1...30

    public let rawValue: UInt8

    public init?(rawValue: UInt8) {
        guard Self.range.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(integerLiteral value: UInt8) {
        guard let channel = Self(rawValue: value) else { preconditionFailure("RFCOMM channel must be \(Self.range)") }
        self = channel
    }
}
