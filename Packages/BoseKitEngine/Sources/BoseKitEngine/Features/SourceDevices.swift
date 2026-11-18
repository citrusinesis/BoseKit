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
    private static let listUnknownPrefixLength = 1
    private static let infoUnknownLength = 2
    private static let connectedBit: UInt8 = 0x01
    private static let requestingHostBit: UInt8 = 0x02

    static func decodeList(_ payload: [UInt8]) throws -> [BluetoothAddress] {
        try PayloadReader.parse(payload, end: .exact) { reader in
            try reader.skip(listUnknownPrefixLength)
            var addresses: [BluetoothAddress] = []
            while !reader.isAtEnd { addresses.append(try reader.bluetoothAddress()) }
            return addresses
        }
    }

    static func decodeInfo(_ payload: [UInt8], for address: BluetoothAddress,
                           activeSource: BluetoothAddress?) throws -> SourceDevice {
        try PayloadReader.parse(payload, end: .exact) { reader in
            guard try reader.bluetoothAddress() == address else {
                throw BoseError.invalidPayload("Device info is for another address")
            }
            let status = try reader.u8()
            try reader.skip(infoUnknownLength)
            return SourceDevice(address: address,
                                name: try reader.remainingString(.utf8),
                                isConnected: status & connectedBit != 0,
                                isRequestingHost: status & requestingHostBit != 0,
                                isActiveSource: address == activeSource)
        }
    }
}
