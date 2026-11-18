public struct BluetoothProductIdentity: Equatable, Sendable {
    public let vendorIDSource: UInt16
    public let vendorID: UInt16
    public let productID: UInt16

    public init(vendorIDSource: UInt16, vendorID: UInt16, productID: UInt16) {
        self.vendorIDSource = vendorIDSource
        self.vendorID = vendorID
        self.productID = productID
    }

    public var isBose: Bool {
        (vendorIDSource == 1 && vendorID == 0x009e) ||
        (vendorIDSource == 2 && vendorID == 0x05a7)
    }
}

public struct PairedBluetoothDevice: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let identity: BluetoothProductIdentity?
    public let isConnected: Bool

    public func profile(in registry: DeviceRegistry) -> DeviceProfile? {
        guard let identity, identity.isBose else { return nil }
        return registry.profile(productID: identity.productID)
    }
}

public struct BluetoothAddress: Hashable, Sendable, CustomStringConvertible {
    public let bytes: [UInt8]

    public init?(bytes: [UInt8]) {
        guard bytes.count == 6 else { return nil }
        self.bytes = bytes
    }

    public init?(string: String) {
        let parts = string.split(omittingEmptySubsequences: false) { $0 == ":" || $0 == "-" }
        guard parts.count == 6, parts.allSatisfy({ $0.count == 2 }) else { return nil }
        let values = parts.compactMap { UInt8($0, radix: 16) }
        self.init(bytes: values)
    }

    public var description: String {
        bytes.map { hex($0) }.joined(separator: ":")
    }

    private func hex(_ byte: UInt8) -> String {
        let digits = Array("0123456789ABCDEF")
        return String([digits[Int(byte >> 4)], digits[Int(byte & 0x0f)]])
    }
}
