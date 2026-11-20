import Foundation
import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct ConnectionMaintenanceTests {
    @Test func pollingKeepsControlsEnabledAndPreservesUserAction() async throws {
        let fixture = HeadsetFixture()
        let controller = fixture.controller
        await controller.connect()
        controller.attachView()
        await fixture.headset.holdNext(.battery, .get)
        let poll = Task { await controller.maintain() }
        await fixture.headset.waitUntilHeld()
        #expect(!controller.busy)
        var performed = false
        let action = Task {
            await controller.perform { _ in
                performed = true
                return nil
            }
        }
        await until { controller.busy }
        #expect(!performed)
        await fixture.headset.release()
        await poll.value
        #expect(await action.value)
        #expect(performed)
        #expect(controller.connected)
        await controller.disconnect()
    }

    @Test func discoveredDeviceConnectsWithoutExistingMacAudioConnection() async throws {
        let fixture = HeadsetFixture()
        let controller = fixture.controller
        await controller.maintain()
        #expect(controller.connected)
        #expect(controller.battery?.percentage == 90)
        await controller.disconnect()
        await controller.maintain()
        #expect(!controller.connected)
        #expect(await fixture.headset.requests.count == 1)
    }

    @Test func maintenanceKeepsAHealthySession() async throws {
        let fixture = HeadsetFixture()
        let controller = fixture.controller
        await controller.connect()
        #expect(controller.connected)
        #expect(controller.battery?.percentage == 90)
        controller.attachView()
        await controller.maintain()
        #expect(controller.connected)
        #expect(await fixture.headset.closes == 0)
        #expect(await fixture.headset.requests.count == 2)
        await controller.disconnect()
    }

    @Test func connectionOpenedAfterCloseIsDiscarded() async throws {
        let headset = FakeHeadset()
        let gate = Gate()
        let controller = DeviceController(id: "test", name: "Test", profile: HeadsetFixture.profile()) { _, profile in
            await gate.pass()
            return try await BoseDevice.connect(profile: profile, transport: headset)
        }
        let connecting = Task { await controller.connect() }
        await gate.waitUntilEntered()
        await controller.closeConnection()
        await gate.open()
        await connecting.value
        #expect(!controller.connected)
        #expect(controller.error == nil)
        #expect(await headset.closes > 0)
    }

    @Test func lostSessionIsDetectedWithoutReplayingWrites() async throws {
        let fixture = HeadsetFixture()
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.close()
        controller.attachView()
        await controller.maintain()
        #expect(!controller.connected)
        #expect(controller.error == .engine(.disconnected))
        #expect(await fixture.headset.requests.allSatisfy { $0[2] == BMAPOperator.get.rawValue })
    }

    @Test func userActionPreemptsRemainingRefreshReads() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .multipoint: .read, .autoPause: .read])
        let controller = fixture.controller
        await controller.connect()
        #expect(await fixture.headset.requests.count == 3)
        await fixture.headset.holdNext(.battery, .get)
        let poll = Task { await controller.refresh(.full) }
        await fixture.headset.waitUntilHeld()
        let action = Task { await controller.perform { _ in nil } }
        await until { controller.busy }
        await fixture.headset.release()
        await poll.value
        #expect(await action.value)
        let addresses = await fixture.headset.requests.map { BMAPAddress($0[0], $0[1]) }
        #expect(addresses == [.battery, .multipoint, .autoPause, .battery, .battery, .multipoint, .autoPause])
        await controller.disconnect()
    }

    @Test func widerRefreshRunsAfterANarrowerOneInFlight() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .multipoint: .read])
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.holdNext(.battery, .get)
        let probe = Task { await controller.refresh(.probe) }
        await fixture.headset.waitUntilHeld()
        let full = Task { await controller.refresh(.full) }
        await Task.yield()
        await fixture.headset.release()
        await probe.value
        await full.value
        #expect(await fixture.headset.requestCount(.battery) == 3)
        #expect(await fixture.headset.requestCount(.multipoint) == 2)
        await controller.disconnect()
    }

    @Test func narrowerRefreshJoinsAWiderOneInFlight() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .multipoint: .read])
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.holdNext(.battery, .get)
        let full = Task { await controller.refresh(.full) }
        await fixture.headset.waitUntilHeld()
        let live = Task { await controller.refresh(.live) }
        await Task.yield()
        await fixture.headset.release()
        await full.value
        await live.value
        #expect(await fixture.headset.requestCount(.battery) == 2)
        #expect(await fixture.headset.requestCount(.multipoint) == 2)
        await controller.disconnect()
    }

    @Test(arguments: [BMAPErrorCode.unknown, .invalidData, BMAPErrorCode(rawValue: 0x42), nil])
    func indeterminateRejectionIsReprobedOnlyByFullRefresh(_ code: BMAPErrorCode?) async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .anr: .read, .multipoint: .read])
        let controller = fixture.controller
        await fixture.headset.reject(.anr, .get, code: code)
        await fixture.headset.reject(.multipoint, .get, code: code)
        await controller.connect()
        #expect(controller.connected)
        #expect(controller.unavailable == [.anr, .multipoint])
        #expect(!controller.supports(.anr))
        await fixture.headset.accept(.anr)
        await fixture.headset.accept(.multipoint)
        await controller.refresh(.live)
        #expect(await fixture.headset.requestCount(.anr) == 1)
        #expect(controller.anr == nil)
        await controller.refresh(.full)
        #expect(await fixture.headset.requestCount(.anr) == 2)
        #expect(controller.unavailable.isEmpty)
        #expect(controller.anr == .high)
        #expect(controller.multipoint != nil)
        await controller.disconnect()
    }

    @Test(arguments: [BMAPErrorCode.functionBlockNotSupported, .functionNotSupported, .operatorNotSupported])
    func permanentRejectionIsNeverReprobed(_ code: BMAPErrorCode) async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .anr: .read, .multipoint: .read])
        let controller = fixture.controller
        await fixture.headset.reject(.anr, .get, code: code)
        await controller.connect()
        #expect(controller.unavailable == [.anr])
        #expect(!controller.supports(.anr))
        await fixture.headset.accept(.anr)
        await controller.refresh(.full)
        await controller.refresh(.live)
        #expect(await fixture.headset.requestCount(.anr) == 1)
        #expect(await fixture.headset.requestCount(.multipoint) == 2)
        #expect(controller.unavailable == [.anr])
        #expect(controller.anr == nil)
        await controller.disconnect()
    }

    @Test(arguments: [BMAPErrorCode.dataUnavailable, .runtime, .timeout, .invalidState, .busy])
    func transientRejectionKeepsTheShownValueAndRetries(_ code: BMAPErrorCode) async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .anr: .read, .multipoint: .read,
                                                .sourceDevices: .read])
        let controller = fixture.controller
        await controller.connect()
        let battery = try #require(controller.battery)
        let multipoint = controller.multipoint
        #expect(multipoint != nil)
        let sourceDevices = controller.sourceDevices
        #expect(!sourceDevices.isEmpty)
        #expect(controller.anr == .high)
        for address in [BMAPAddress.battery, .anr, .multipoint, .deviceList] {
            await fixture.headset.reject(address, .get, code: code)
        }
        await controller.refresh(.full)
        #expect(controller.unavailable.isEmpty)
        #expect(controller.battery == battery)
        #expect(controller.anr == .high)
        #expect(controller.multipoint == multipoint)
        #expect(controller.sourceDevices == sourceDevices)
        #expect(controller.error == nil)
        await controller.refresh(.live)
        #expect(await fixture.headset.requestCount(.anr) == 3)
        #expect(controller.anr == .high)
        await fixture.headset.accept(.anr)
        await controller.refresh(.live)
        #expect(await fixture.headset.requestCount(.anr) == 4)
        #expect(controller.anr == .high)
        await controller.disconnect()
    }
}
