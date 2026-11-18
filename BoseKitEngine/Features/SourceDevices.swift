public struct SourceDevice: Equatable, Sendable, Identifiable {
    public let address: BluetoothAddress
    public let name: String
    public let isConnected: Bool
    public let isRequestingHost: Bool
    public let isActiveSource: Bool

    public var id: BluetoothAddress { address }

    public init(address: BluetoothAddress, name: String, isConnected: Bool,
                isRequestingHost: Bool, isActiveSource: Bool) {
        self.address = address
        self.name = name
        self.isConnected = isConnected
        self.isRequestingHost = isRequestingHost
        self.isActiveSource = isActiveSource
    }
}

enum SourceDeviceCodec {
    static func decodeList(_ payload: [UInt8]) throws -> [BluetoothAddress] {
        guard !payload.isEmpty, (payload.count - 1).isMultiple(of: 6) else {
            throw BoseError.invalidPayload("Device list")
        }
        return stride(from: 1, to: payload.count, by: 6).compactMap {
            BluetoothAddress(bytes: Array(payload[$0..<$0 + 6]))
        }
    }

    static func decodeInfo(_ payload: [UInt8], for address: BluetoothAddress,
                           activeSource: BluetoothAddress?) throws -> SourceDevice {
        guard payload.count >= 9, Array(payload.prefix(6)) == address.bytes else {
            throw BoseError.invalidPayload("Device info")
        }
        let status = payload[6]
        return SourceDevice(address: address,
                            name: String(decoding: payload.dropFirst(9), as: UTF8.self),
                            isConnected: status & 0x01 != 0,
                            isRequestingHost: status & 0x02 != 0,
                            isActiveSource: address == activeSource)
    }
}
