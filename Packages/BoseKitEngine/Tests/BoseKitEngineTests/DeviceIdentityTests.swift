import Testing
@testable import BoseKitEngine

struct DeviceIdentityTests {
    @Test func vendorIDSourcePreventsFalseProductMatches() {
        #expect(BluetoothProductIdentity(vendorIDSource: 1, vendorID: 0x009e, productID: 0x4066).isBose)
        #expect(BluetoothProductIdentity(vendorIDSource: 2, vendorID: 0x05a7, productID: 0x4082).isBose)
        #expect(!BluetoothProductIdentity(vendorIDSource: 2, vendorID: 0x009e, productID: 0x4066).isBose)
    }

    @Test func pairedDeviceResolvesProfileOnlyForKnownBoseProducts() throws {
        let registry = DeviceRegistry.standard
        func paired(_ identity: BluetoothProductIdentity?) -> PairedBluetoothDevice {
            PairedBluetoothDevice(id: "AC:BF:71:0A:1B:2C", name: "Headphones", identity: identity, isConnected: true)
        }
        let known = paired(BluetoothProductIdentity(vendorIDSource: 1, vendorID: 0x009e, productID: 0x4066))
        let wrongSource = paired(BluetoothProductIdentity(vendorIDSource: 2, vendorID: 0x009e, productID: 0x4066))
        let unknownProduct = paired(BluetoothProductIdentity(vendorIDSource: 1, vendorID: 0x009e, productID: 0xffff))
        #expect(known.profile(in: registry)?.id == "lonestarr")
        #expect(wrongSource.profile(in: registry) == nil)
        #expect(unknownProduct.profile(in: registry) == nil)
        #expect(paired(nil).profile(in: registry) == nil)
    }
}
