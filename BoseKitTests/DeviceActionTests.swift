import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct DeviceActionTests {
    @Test func queuedActionsBothRunInOrderWithOneRefreshAfterward() async throws {
        let fixture = HeadsetFixture()
        let controller = fixture.controller
        await controller.connect()
        let gate = Gate()
        var order: [Int] = []
        let first = Task {
            await controller.perform(refreshing: .probe) { _ in
                await gate.pass()
                order.append(1)
                return nil
            }
        }
        await gate.waitUntilEntered()
        let second = Task { await controller.perform(refreshing: .probe) { _ in
            order.append(2)
            return nil
        } }
        await Task.yield()
        #expect(controller.busy)
        await gate.open()
        #expect(await first.value)
        #expect(await second.value)
        #expect(order == [1, 2])
        #expect(!controller.busy)
        #expect(await fixture.headset.requestCount(.battery) == 2)
        await controller.disconnect()
    }

    @Test func failedQueuedActionStaysVisibleAfterALaterSuccess() async throws {
        let fixture = HeadsetFixture()
        let controller = fixture.controller
        await controller.connect()
        let gate = Gate()
        let failing = Task {
            await controller.perform { _ in
                await gate.pass()
                throw BoseError.invalidState(.windBlockLocksCNC)
            }
        }
        await gate.waitUntilEntered()
        let succeeding = Task { await controller.perform { _ in nil } }
        await Task.yield()
        await gate.open()
        #expect(await failing.value == false)
        #expect(await succeeding.value)
        #expect(controller.error == .engine(.invalidState(.windBlockLocksCNC)))
        await controller.disconnect()
    }

    @Test func rejectedPowerOffKeepsTheConnection() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .power: .write])
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.reject(.power, .start)
        await controller.powerOff()
        #expect(controller.connected)
        #expect(!controller.isSuspended)
        #expect(controller.error == .engine(.device(.power, code: .operatorNotSupported, detail: nil)))
        await controller.disconnect()
    }

    @Test func powerOffSuspendsReconnection() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .power: .write])
        let controller = fixture.controller
        await controller.connect()
        await controller.powerOff()
        #expect(!controller.connected)
        #expect(controller.isSuspended)
        #expect(controller.error == nil)
        await controller.maintain()
        #expect(!controller.connected)
    }

    @Test func powerOffThatDropsTheLinkStillSuspends() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .power: .write])
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.dropLink(on: .power)
        await controller.powerOff()
        #expect(!controller.connected)
        #expect(controller.isSuspended)
        await controller.maintain()
        #expect(!controller.connected)
    }
}
