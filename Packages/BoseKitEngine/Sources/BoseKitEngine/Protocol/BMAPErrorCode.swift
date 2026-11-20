public struct BMAPErrorCode: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    public enum Disposition: Hashable, Sendable {
        case permanent
        case transient
        case indeterminate
    }

    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let unknown = Self(rawValue: 0x00)
    public static let length = Self(rawValue: 0x01)
    public static let checksum = Self(rawValue: 0x02)
    public static let functionBlockNotSupported = Self(rawValue: 0x03)
    public static let functionNotSupported = Self(rawValue: 0x04)
    public static let operatorNotSupported = Self(rawValue: 0x05)
    public static let invalidData = Self(rawValue: 0x06)
    public static let dataUnavailable = Self(rawValue: 0x07)
    public static let runtime = Self(rawValue: 0x08)
    public static let timeout = Self(rawValue: 0x09)
    public static let invalidState = Self(rawValue: 0x0A)
    public static let deviceNotFound = Self(rawValue: 0x0B)
    public static let busy = Self(rawValue: 0x0C)
    public static let functionBlockSpecific = Self(rawValue: 0xFF)

    public var name: String? {
        switch self {
        case .unknown: "Unknown"
        case .length: "Length"
        case .checksum: "Chksum"
        case .functionBlockNotSupported: "FblockNotSupp"
        case .functionNotSupported: "FuncNotSupp"
        case .operatorNotSupported: "OpNotSupp"
        case .invalidData: "InvalidData"
        case .dataUnavailable: "DataUnavailable"
        case .runtime: "Runtime"
        case .timeout: "Timeout"
        case .invalidState: "InvalidState"
        case .deviceNotFound: "DeviceNotFound"
        case .busy: "Busy"
        case .functionBlockSpecific: "FblockSpecific"
        default: nil
        }
    }

    public var disposition: Disposition {
        switch self {
        case .functionBlockNotSupported, .functionNotSupported, .operatorNotSupported: .permanent
        case .dataUnavailable, .runtime, .timeout, .invalidState, .busy: .transient
        default: .indeterminate
        }
    }

    public var description: String {
        let digits = String(rawValue, radix: 16, uppercase: true)
        let hex = "0x" + (digits.count == 1 ? "0" + digits : digits)
        return name.map { "\(hex) \($0)" } ?? hex
    }
}
