import BoseKitEngine
import Testing
@testable import BoseKitProbe

struct ProbeTargetTests {
    private let lonestarr = BluetoothProductIdentity(vendorIDSource: 1, vendorID: 0x009e, productID: 0x4066)

    private func paired(_ id: String, name: String = "Headphones", identity: BluetoothProductIdentity?,
                        connected: Bool = false) -> PairedBluetoothDevice {
        PairedBluetoothDevice(id: id, name: name, identity: identity, isConnected: connected)
    }

    @Test func entriesSharingAnAddressBecomeOneTargetConnectedIfEitherIs() {
        let targets = ProbeTarget.merging([
            paired("ac-bf-71-0a-1b-2c", identity: lonestarr),
            paired("AC-BF-71-0A-1B-2C", identity: lonestarr, connected: true),
        ], registry: .standard)
        #expect(targets == [ProbeTarget(address: "ac-bf-71-0a-1b-2c", name: "Headphones",
                                        profileID: "lonestarr", isConnected: true)])
    }

    @Test func distinctAddressesStaySeparateInPairingOrder() {
        let targets = ProbeTarget.merging([
            paired("ac-bf-71-0a-1b-2c", name: "First", identity: lonestarr),
            paired("ac-bf-71-0a-1b-2d", name: "Second", identity: lonestarr),
        ], registry: .standard)
        #expect(targets.map(\.name) == ["First", "Second"])
    }

    @Test func nonBoseDevicesAreLeftOutAndUnknownBoseProductsHaveNoProfile() {
        let unknownBose = BluetoothProductIdentity(vendorIDSource: 1, vendorID: 0x009e, productID: 0xffff)
        let other = BluetoothProductIdentity(vendorIDSource: 1, vendorID: 0x004c, productID: 0x4066)
        let targets = ProbeTarget.merging([
            paired("00-00-00-00-00-01", identity: other),
            paired("00-00-00-00-00-02", identity: nil),
            paired("00-00-00-00-00-03", identity: unknownBose),
        ], registry: .standard)
        #expect(targets == [ProbeTarget(address: "00-00-00-00-00-03", name: "Headphones",
                                        profileID: nil, isConnected: false)])
    }
}
