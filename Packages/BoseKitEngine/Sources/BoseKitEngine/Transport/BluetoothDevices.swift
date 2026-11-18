public struct BluetoothProductIdentity: Equatable, Sendable {
    public let vendorIDSource: UInt16
    public let vendorID: UInt16
    public let productID: UInt16

    public init(vendorIDSource: UInt16, vendorID: UInt16, productID: UInt16) {
        self.vendorIDSource = vendorIDSource
        self.vendorID = vendorID
        self.productID = productID
    }

    private enum VendorIDSource: UInt16 {
        case bluetoothSIG = 1
        case usbImplementersForum = 2
    }

    private static let boseVendorIDs: [VendorIDSource: UInt16] = [
        .bluetoothSIG: 0x009e,
        .usbImplementersForum: 0x05a7,
    ]

    public var isBose: Bool {
        VendorIDSource(rawValue: vendorIDSource).flatMap { Self.boseVendorIDs[$0] } == vendorID
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
    static let byteCount = 6
    private static let separators: Set<Character> = [":", "-"]

    public let bytes: [UInt8]

    public init?(bytes: [UInt8]) {
        guard bytes.count == Self.byteCount else { return nil }
        self.bytes = bytes
    }

    public init?(string: String) {
        guard let separator = string.first(where: Self.separators.contains) else { return nil }
        let parts = string.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == Self.byteCount else { return nil }
        var values: [UInt8] = []
        for part in parts {
            guard part.count == 2, part.allSatisfy({ $0.isASCII && $0.isHexDigit }),
                  let value = UInt8(part, radix: 16) else { return nil }
            values.append(value)
        }
        self.init(bytes: values)
    }

    public var description: String {
        bytes.map { byte in
            let digits = String(byte, radix: 16, uppercase: true)
            return digits.count == 1 ? "0" + digits : digits
        }.joined(separator: ":")
    }
}

extension PayloadReader {
    mutating func bluetoothAddress() throws -> BluetoothAddress {
        guard let address = BluetoothAddress(bytes: try bytes(BluetoothAddress.byteCount)) else {
            throw BoseError.invalidPayload("Bluetooth address")
        }
        return address
    }
}
