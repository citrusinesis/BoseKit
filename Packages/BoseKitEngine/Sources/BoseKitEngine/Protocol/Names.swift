public struct DeviceName: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public static let maximumByteCount = nameByteLimit

    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty, fitsNameField(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        guard let name = Self(rawValue: value) else {
            preconditionFailure("Device name must be 1...\(Self.maximumByteCount) UTF-8 bytes without NUL")
        }
        self = name
    }
}

public struct ModeName: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public static let maximumByteCount = nameByteLimit

    public let rawValue: String

    public init?(rawValue: String) {
        guard fitsNameField(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        guard let name = Self(rawValue: value) else {
            preconditionFailure("Mode name must be at most \(Self.maximumByteCount) UTF-8 bytes without NUL")
        }
        self = name
    }
}

private let nameByteLimit = 31

private func fitsNameField(_ value: String) -> Bool {
    value.utf8.count <= nameByteLimit && !value.utf8.contains(0)
}
