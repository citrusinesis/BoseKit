public struct ResponseRule: Sendable {
    public enum Completion: Sendable {
        case first(Set<BMAPOperator>)
        case quiet(Duration)
    }

    public let addresses: Set<BMAPAddress>
    public let completion: Completion
    public let accepts: @Sendable (BMAPPacket) -> Bool
    public let isComplete: (@Sendable ([BMAPPacket]) -> Bool)?

    public init(
        addresses: Set<BMAPAddress>,
        completion: Completion,
        accepts: @escaping @Sendable (BMAPPacket) -> Bool = { _ in true },
        isComplete: (@Sendable ([BMAPPacket]) -> Bool)? = nil
    ) {
        self.addresses = addresses
        self.completion = completion
        self.accepts = accepts
        self.isComplete = isComplete
    }
}

public struct BMAPCommand<Response: Sendable>: Sendable {
    public let packet: BMAPPacket
    public let rule: ResponseRule
    public let timeout: Duration
    let decode: @Sendable ([BMAPPacket]) throws -> Response

    public init(
        packet: BMAPPacket,
        rule: ResponseRule? = nil,
        timeout: Duration = .seconds(4),
        decode: @escaping @Sendable ([BMAPPacket]) throws -> Response
    ) {
        self.packet = packet
        self.rule = rule ?? ResponseRule(
            addresses: [packet.address],
            completion: .first(packet.operation == .start ? [.result] : [.status, .result])
        )
        self.timeout = timeout
        self.decode = decode
    }
}

func require(_ payload: [UInt8], count: Int) throws {
    guard payload.count >= count else {
        throw BoseError.invalidPayload("Expected at least \(count) bytes, received \(payload.count)")
    }
}
