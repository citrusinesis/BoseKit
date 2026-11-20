@preconcurrency import IOBluetooth

extension RFCOMMTransport {
    nonisolated public static func pairedDevices() throws(PairedDeviceListingError) -> [PairedBluetoothDevice] {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            throw .systemListUnavailable
        }
        return devices.compactMap { device in
            guard let address = device.addressString else { return nil }
            return PairedBluetoothDevice(id: address, name: device.name ?? address,
                                         identity: DeviceIDServiceRecord.identity(of: device),
                                         isConnected: device.isConnected())
        }
    }
}

private enum DeviceIDServiceRecord {
    static let pnpInformationServiceClass: UInt16 = 0x1200

    enum Attribute: BluetoothSDPServiceAttributeID {
        case vendorID = 0x0201
        case productID = 0x0202
        case vendorIDSource = 0x0205
    }

    static func identity(of device: IOBluetoothDevice) -> BluetoothProductIdentity? {
        guard let record = device.getServiceRecord(for: IOBluetoothSDPUUID(uuid16: pnpInformationServiceClass)),
              let vendorID = record.number(for: .vendorID),
              let productID = record.number(for: .productID),
              let vendorIDSource = record.number(for: .vendorIDSource) else { return nil }
        return BluetoothProductIdentity(vendorIDSource: vendorIDSource, vendorID: vendorID, productID: productID)
    }
}

private extension IOBluetoothSDPServiceRecord {
    func number(for attribute: DeviceIDServiceRecord.Attribute) -> UInt16? {
        getAttributeDataElement(attribute.rawValue)?.getNumberValue()?.uint16Value
    }
}
