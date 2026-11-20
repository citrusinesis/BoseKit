import Foundation
import Synchronization
import Testing
import BoseKitEngine
@testable import BoseKit

final class PairedListing: Sendable {
    private let state = Mutex<Result<[PairedBluetoothDevice], PairedDeviceListingError>>(.success([]))

    func list() throws(PairedDeviceListingError) -> [PairedBluetoothDevice] {
        try state.withLock { $0 }.get()
    }

    func set(_ devices: [PairedBluetoothDevice]) {
        state.withLock { $0 = .success(devices) }
    }

    func fail() {
        state.withLock { $0 = .failure(.systemListUnavailable) }
    }
}

@MainActor
struct PairedHeadsets {
    static let boseIdentity = BluetoothProductIdentity(vendorIDSource: 1, vendorID: 0x009e, productID: 1)

    let headsets: [String: FakeHeadset]
    let listing: PairedListing
    let model: BoseAppModel

    init(_ ids: [String], defaults: UserDefaults,
         features: [FeatureID: FeatureAccess] = [.battery: .read]) throws {
        let headsets = Dictionary(uniqueKeysWithValues: ids.map { ($0, FakeHeadset()) })
        let listing = PairedListing()
        self.headsets = headsets
        self.listing = listing
        model = BoseAppModel(
            defaults: defaults,
            registry: try DeviceRegistry(profiles: [HeadsetFixture.profile(features: features)]),
            listPairedDevices: { () throws(PairedDeviceListingError) in try listing.list() },
            connectDevice: { address, profile in
                try await BoseDevice.connect(profile: profile, transport: try #require(headsets[address]))
            })
        pair(ids)
    }

    static func entry(_ id: String, identity: BluetoothProductIdentity? = boseIdentity,
                      isConnected: Bool = false) -> PairedBluetoothDevice {
        PairedBluetoothDevice(id: id, name: id, identity: identity, isConnected: isConnected)
    }

    func pair(_ ids: [String]) {
        listing.set(ids.map { Self.entry($0) })
    }

    func controller(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> DeviceController {
        try #require(model.devices.first { $0.id == id }, sourceLocation: sourceLocation)
    }

    func headset(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> FakeHeadset {
        try #require(headsets[id], sourceLocation: sourceLocation)
    }

    func connect(_ ids: String...) async throws {
        for id in ids {
            let controller = try controller(id)
            await controller.connect()
            #expect(controller.connected)
        }
    }

    func disconnectAll() async {
        for device in model.devices where device.connected { await device.closeConnection() }
    }
}
