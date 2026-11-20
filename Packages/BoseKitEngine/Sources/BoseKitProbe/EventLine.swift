import BoseKitEngine
import Foundation

enum EventLine {
    static func format(_ event: BMAPEvent, time: String) -> String {
        let packet = event.packet
        let columns = [
            time,
            origin(event.origin).padding(toLength: 11, withPad: " ", startingAt: 0),
            RegisterCatalog.column(for: packet.address),
            operation(packet).padding(toLength: 10, withPad: " ", startingAt: 0),
            packet.operation == .error ? errorPayload(packet.payload) : hex(packet.payload),
        ]
        return columns.joined(separator: "  ")
    }

    static func errorPayload(_ payload: [UInt8]) -> String {
        guard let name = payload.first.flatMap({ BMAPErrorCode(rawValue: $0).name }) else { return hex(payload) }
        return "\(hex(payload)) (\(name))"
    }

    static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { byte in
            let digits = String(byte, radix: 16)
            return digits.count == 1 ? "0" + digits : digits
        }.joined(separator: " ")
    }

    private static func origin(_ origin: BMAPEvent.Origin) -> String {
        switch origin {
        case .reply: "reply"
        case .unsolicited: "unsolicited"
        }
    }

    private static func operation(_ packet: BMAPPacket) -> String {
        guard let operation = packet.operation else { return "FLAGS \(hex([packet.flags]))" }
        return switch operation {
        case .set: "SET"
        case .get: "GET"
        case .setGet: "SETGET"
        case .status: "STATUS"
        case .error: "ERROR"
        case .start: "START"
        case .result: "RESULT"
        case .processing: "PROCESSING"
        }
    }
}
