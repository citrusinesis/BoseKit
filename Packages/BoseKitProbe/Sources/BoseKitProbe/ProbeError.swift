import BoseKitEngine

enum ProbeError: Error, Equatable, CustomStringConvertible {
    case usage(String)
    case pairedDevicesUnavailable
    case noSupportedDevice
    case deviceNotPaired(String)
    case ambiguousDevices([String])
    case malformedNotificationState([UInt8])
    case replyNotObserved(BMAPAddress)
    case reconnectFailed(String)
    case connectionLost

    var description: String {
        switch self {
        case .usage(let problem):
            "\(problem)\n\n\(ProbeCommand.usage)"
        case .pairedDevicesUnavailable:
            "macOS did not return the list of paired Bluetooth devices."
        case .noSupportedDevice:
            "No supported Bose device is paired with this Mac."
        case .deviceNotPaired(let address):
            "No supported paired device has the address \(address)."
        case .ambiguousDevices(let addresses):
            "Several supported devices are paired; choose one with --address: \(addresses.joined(separator: ", "))"
        case .malformedNotificationState(let payload):
            "Notification state must be a 4-byte block bitmap, received \(payload.count) bytes."
        case .replyNotObserved(let address):
            "The reply to \(address.block).\(address.function) was not observed in the event stream."
        case .reconnectFailed(let reason):
            "Reconnecting after an unanswered request failed: \(reason)"
        case .connectionLost:
            "The connection to the device closed."
        }
    }
}
