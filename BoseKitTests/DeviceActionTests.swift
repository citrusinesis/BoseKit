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
            }
        }
        await gate.waitUntilEntered()
        let second = Task { await controller.perform(refreshing: .probe) { _ in order.append(2) } }
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
        let succeeding = Task { await controller.perform { _ in } }
        await Task.yield()
        await gate.open()
        #expect(await failing.value == false)
        #expect(await succeeding.value)
        #expect(controller.error == .engine(.invalidState(.windBlockLocksCNC)))
        await controller.disconnect()
    }

    @Test func selectedModeShowsImmediatelyAndIsConfirmed() async throws {
        let fixture = HeadsetFixture.withModes()
        let controller = fixture.controller
        await controller.connect()
        #expect(controller.currentMode == 0)
        let selection = try #require(controller.selectMode(2))
        #expect(controller.currentMode == 2)
        #expect(await selection.value)
        #expect(controller.currentMode == 2)
        #expect(await fixture.headset.currentMode == 2)
        await controller.disconnect()
    }

    @Test func rejectedModeSelectionRollsBack() async throws {
        let fixture = HeadsetFixture.withModes()
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.rejectSelection(of: 2)
        let selection = try #require(controller.selectMode(2))
        #expect(controller.currentMode == 2)
        #expect(await selection.value == false)
        #expect(controller.currentMode == 0)
        #expect(controller.error == .engine(.device(.currentMode, code: 5)))
        #expect(controller.connected)
        await controller.disconnect()
    }

    @Test func rapidSelectionsRollBackToTheLastConfirmedMode() async throws {
        let fixture = HeadsetFixture.withModes()
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.rejectSelection(of: 2)
        await fixture.headset.holdNext(.currentMode, .start)
        let toOne = try #require(controller.selectMode(1))
        await fixture.headset.waitUntilHeld()
        let toTwo = try #require(controller.selectMode(2))
        #expect(controller.currentMode == 2)
        await fixture.headset.release()
        #expect(await toOne.value)
        #expect(await toTwo.value == false)
        #expect(controller.currentMode == 1)
        #expect(await fixture.headset.currentMode == 1)
        await controller.disconnect()
    }

    @Test func rapidSelectionsEndOnTheLastMode() async throws {
        let fixture = HeadsetFixture.withModes()
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.holdNext(.currentMode, .start)
        let toOne = try #require(controller.selectMode(1))
        await fixture.headset.waitUntilHeld()
        let toTwo = try #require(controller.selectMode(2))
        await fixture.headset.release()
        #expect(await toOne.value)
        #expect(await toTwo.value)
        #expect(controller.currentMode == 2)
        #expect(await fixture.headset.currentMode == 2)
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
        #expect(controller.error == .engine(.device(.power, code: 5)))
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
