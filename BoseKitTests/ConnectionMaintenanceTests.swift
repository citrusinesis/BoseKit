import Foundation
import Testing
import BoseKitEngine
@testable import BoseKit

private actor BatteryTransport: BMAPTransport {
    private let pair = AsyncThrowingStream<[UInt8], any Error>.makeStream()
    private(set) var closes = 0
    private(set) var requests: [[UInt8]] = []
    private var holdNext = false
    private var held = false
    private var requestWaiter: CheckedContinuation<Void, Never>?
    func holdNextResponse() { holdNext = true }
    func waitForHeldRequest() async {
        if held { return }
        await withCheckedContinuation { requestWaiter = $0 }
    }
    func releaseResponse() {
        held = false
        pair.continuation.yield([2, 2, 3, 1, 90])
    }
    func open() -> AsyncThrowingStream<[UInt8], any Error> { pair.stream }
    func write(_ bytes: [UInt8]) {
        requests.append(bytes)
        if holdNext {
            holdNext = false
            held = true
            requestWaiter?.resume()
            requestWaiter = nil
            return
        }
        pair.continuation.yield([bytes[0], bytes[1], 3, 1, 90])
    }
    func close() { closes += 1; pair.continuation.finish() }
}

@MainActor
struct ConnectionMaintenanceTests {
    @Test func menuFollowsLiveConnectionAndBatteryWithoutPollingVisibility() async throws {
        let transport = BatteryTransport()
        let profile = try DeviceProfile(id: "test", name: "Test", productIDs: [1],
                                        rfcommChannel: 2, features: [.battery: .read], provenance: "Synthetic")
        let device = DeviceController(id: "test", name: "Test", profile: profile) { _, profile in
            try await BoseDevice.connect(profile: profile, transport: transport)
        }
        let model = BoseAppModel()
        let oldHide = model.hideWhenUnavailable
        let oldBattery = model.showBattery
        defer {
            model.hideWhenUnavailable = oldHide
            model.showBattery = oldBattery
        }
        model.devices = [
            DeviceController(id: "offline", name: "Offline", profile: profile), device
        ]
        model.selectedID = "offline"
        model.hideWhenUnavailable = true
        model.showBattery = true
        #expect(!model.menuInserted)
        #expect(model.menuBatteryPercentage == nil)
        await device.connect()
        #expect(model.menuInserted)
        #expect(model.menuBatteryPercentage == 90)
        model.showBattery = false
        #expect(model.menuBatteryPercentage == nil)
        model.showBattery = true
        device.nativeConnected = true
        await device.disconnect()
        #expect(!model.menuInserted)
        #expect(model.menuBatteryPercentage == nil)
    }

    @Test func pollingKeepsControlsEnabledAndPreservesUserAction() async throws {
        let transport = BatteryTransport()
        let profile = try DeviceProfile(id: "test", name: "Test", productIDs: [1],
                                        rfcommChannel: 2, features: [.battery: .read], provenance: "Synthetic")
        let controller = DeviceController(id: "test", name: "Test", profile: profile) { _, profile in
            try await BoseDevice.connect(profile: profile, transport: transport)
        }
        await controller.connect()
        controller.attachView()
        await transport.holdNextResponse()
        let poll = Task { await controller.maintain() }
        await transport.waitForHeldRequest()
        #expect(!controller.busy)
        var performed = false
        let action = Task { await controller.perform { _ in performed = true } }
        await Task.yield()
        #expect(!performed)
        #expect(!controller.busy)
        await transport.releaseResponse()
        await poll.value
        #expect(await action.value)
        #expect(performed)
        #expect(controller.connected)
        await controller.disconnect()
    }

    @Test func discoveredDeviceConnectsWithoutExistingMacAudioConnection() async throws {
        let transport = BatteryTransport()
        let profile = try DeviceProfile(id: "test", name: "Test", productIDs: [1],
                                        rfcommChannel: 2, features: [.battery: .read], provenance: "Synthetic")
        let controller = DeviceController(id: "test", name: "Test", profile: profile) { _, profile in
            try await BoseDevice.connect(profile: profile, transport: transport)
        }
        #expect(!controller.nativeConnected)
        await controller.maintain()
        #expect(controller.connected)
        #expect(controller.battery?.percentage == 90)
        await controller.disconnect()
        await controller.maintain()
        #expect(!controller.connected)
        #expect(await transport.requests.count == 1)
    }

    @Test func healthyRFCOMMSurvivesStaleBluetoothDiscovery() async throws {
        let transport = BatteryTransport()
        let profile = try DeviceProfile(id: "test", name: "Test", productIDs: [1],
                                        rfcommChannel: 2, features: [.battery: .read], provenance: "Synthetic")
        let controller = DeviceController(id: "test", name: "Test", profile: profile) { _, profile in
            try await BoseDevice.connect(profile: profile, transport: transport)
        }
        await controller.connect()
        #expect(controller.connected)
        #expect(controller.battery?.percentage == 90)
        controller.nativeConnected = false
        controller.attachView()
        await controller.maintain()
        #expect(controller.connected)
        #expect(await transport.closes == 0)
        #expect(await transport.requests.count == 2)
        await controller.disconnect()
    }

    @Test func lostSessionIsDetectedWithoutReplayingWrites() async throws {
        let transport = BatteryTransport()
        let profile = try DeviceProfile(id: "test", name: "Test", productIDs: [1],
                                        rfcommChannel: 2, features: [.battery: .read], provenance: "Synthetic")
        let controller = DeviceController(id: "test", name: "Test", profile: profile) { _, profile in
            try await BoseDevice.connect(profile: profile, transport: transport)
        }
        await controller.connect()
        await transport.close()
        controller.attachView()
        await controller.maintain()
        #expect(!controller.connected)
        #expect(controller.error != nil)
        #expect(await transport.requests.allSatisfy { $0[2] == 1 })
    }

    @Test func userActionPreemptsRemainingRefreshReads() async throws {
        let transport = BatteryTransport()
        let profile = try DeviceProfile(id: "test", name: "Test", productIDs: [1], rfcommChannel: 2,
                                        features: [.battery: .read, .multipoint: .read, .autoPause: .read],
                                        provenance: "Synthetic")
        let controller = DeviceController(id: "test", name: "Test", profile: profile) { _, profile in
            try await BoseDevice.connect(profile: profile, transport: transport)
        }
        await controller.connect()
        #expect(await transport.requests.count == 3)
        await transport.holdNextResponse()
        let poll = Task { await controller.refresh(.full) }
        await transport.waitForHeldRequest()
        let action = Task { await controller.perform { _ in } }
        await Task.yield()
        await transport.releaseResponse()
        await poll.value
        #expect(await action.value)
        let addresses = await transport.requests.map { [$0[0], $0[1]] }
        #expect(addresses.count == 7)
        #expect(addresses[3] == [2, 2])
        #expect(addresses[4] == [2, 2])
        await controller.disconnect()
    }
}
