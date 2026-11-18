public struct BMAPAddress: Hashable, Sendable {
    public let block: UInt8
    public let function: UInt8

    public init(_ block: UInt8, _ function: UInt8) {
        self.block = block
        self.function = function
    }
}

public enum BMAPOperator: UInt8, Sendable {
    case set = 0, get, setGet, status, error, start, result, processing
}

public struct BMAPPacket: Equatable, Sendable {
    public let address: BMAPAddress
    public let flags: UInt8
    public let payload: [UInt8]
    public var operation: BMAPOperator? { BMAPOperator(rawValue: flags & 0x0f) }

    public init(address: BMAPAddress, operation: BMAPOperator, payload: [UInt8] = []) throws {
        try self.init(address: address, flags: operation.rawValue, payload: payload)
    }

    public init(address: BMAPAddress, flags: UInt8, payload: [UInt8]) throws {
        guard payload.count <= 255 else { throw BoseError.invalidArgument("Payload exceeds 255 bytes") }
        self.address = address
        self.flags = flags
        self.payload = payload
    }

    public var bytes: [UInt8] {
        [address.block, address.function, flags, UInt8(payload.count)] + payload
    }
}

public struct BMAPDecoder: Sendable {
    private var buffer: [UInt8] = []

    public init() {}

    public mutating func append(_ bytes: [UInt8]) throws -> [BMAPPacket] {
        buffer.append(contentsOf: bytes)
        var offset = 0
        var packets: [BMAPPacket] = []
        while buffer.count - offset >= 4 {
            let end = offset + 4 + Int(buffer[offset + 3])
            guard end <= buffer.count else { break }
            packets.append(try BMAPPacket(
                address: BMAPAddress(buffer[offset], buffer[offset + 1]),
                flags: buffer[offset + 2],
                payload: Array(buffer[(offset + 4)..<end])
            ))
            offset = end
        }
        buffer.removeFirst(offset)
        return packets
    }

    public var bufferedByteCount: Int { buffer.count }
}
