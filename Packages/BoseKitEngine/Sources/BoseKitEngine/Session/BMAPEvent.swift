public struct BMAPEvent: Equatable, Sendable {
    public enum Origin: Sendable {
        case reply
        case unsolicited
    }

    public let packet: BMAPPacket
    public let origin: Origin

    public init(packet: BMAPPacket, origin: Origin) {
        self.packet = packet
        self.origin = origin
    }
}
