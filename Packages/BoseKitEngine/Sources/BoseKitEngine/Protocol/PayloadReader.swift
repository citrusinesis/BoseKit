import Foundation

enum PayloadEnd {
    case exact
    case trailingBytesAllowed
}

enum PayloadText {
    case ascii
    case utf8
}

struct PayloadReader {
    private let payload: [UInt8]
    private var offset = 0

    private init(_ payload: [UInt8]) {
        self.payload = payload
    }

    static func parse<Value>(
        _ payload: [UInt8], end: PayloadEnd, _ body: (inout PayloadReader) throws -> Value
    ) throws -> Value {
        var reader = PayloadReader(payload)
        let value = try body(&reader)
        if end == .exact { try reader.requireEnd() }
        return value
    }

    var isAtEnd: Bool { offset == payload.count }

    func requireEnd() throws {
        guard isAtEnd else { throw BoseError.invalidPayload("Expected \(offset) bytes, received \(payload.count)") }
    }

    mutating func u8() throws -> UInt8 {
        try bytes(1)[0]
    }

    mutating func u16() throws -> UInt16 {
        try bytes(2).reduce(0) { $0 << 8 | UInt16($1) }
    }

    mutating func u32() throws -> UInt32 {
        try bytes(4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    mutating func bool() throws -> Bool {
        try u8() != 0
    }

    mutating func skip(_ count: Int) throws {
        _ = try bytes(count)
    }

    mutating func bytes(_ count: Int) throws -> [UInt8] {
        guard count <= payload.count - offset else {
            throw BoseError.invalidPayload("Expected at least \(offset + count) bytes, received \(payload.count)")
        }
        defer { offset += count }
        return Array(payload[offset..<(offset + count)])
    }

    mutating func remainingBytes() -> [UInt8] {
        defer { offset = payload.count }
        return Array(payload[offset...])
    }

    mutating func nulTerminatedString(fieldLength: Int) throws -> String {
        try Self.decode(try bytes(fieldLength).prefix { $0 != 0 }, as: .utf8)
    }

    mutating func remainingString(_ text: PayloadText) throws -> String {
        var bytes = remainingBytes()
        while bytes.last == 0 { bytes.removeLast() }
        guard !bytes.contains(0) else { throw BoseError.invalidPayload("Text contains an embedded NUL") }
        return try Self.decode(bytes, as: text)
    }

    private static func decode(_ bytes: some Collection<UInt8>, as text: PayloadText) throws -> String {
        let encoding: String.Encoding = switch text {
        case .ascii: .ascii
        case .utf8: .utf8
        }
        guard let value = String(bytes: bytes, encoding: encoding) else {
            throw BoseError.invalidPayload("Invalid \(text) text")
        }
        return value
    }
}
