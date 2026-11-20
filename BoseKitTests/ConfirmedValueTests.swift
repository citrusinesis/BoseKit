import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct ConfirmedValueTests {
    @Test func toggleShowsTheConfirmedValueWithoutARefresh() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .autoPause: .readWrite])
        let controller = fixture.controller
        await fixture.headset.store([0], at: .autoPause)
        await controller.connect()
        #expect(controller.autoPause == false)
        let before = await fixture.requestCount()
        let revision = controller.refreshRevision
        await fixture.settle({ controller.setAutoPause(true) }, holding: .autoPause, .setGet)
        #expect(controller.autoPause == true)
        #expect(controller.refreshRevision == revision + 1)
        #expect(await fixture.headset.requests(after: before) == [
            FakeRequest(.autoPause, .setGet), FakeRequest(.autoPause, .get),
        ])
        await controller.disconnect()
    }

    @Test func failedActionRefreshesEverything() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .autoPause: .readWrite])
        let controller = fixture.controller
        await fixture.headset.store([0], at: .autoPause)
        await controller.connect()
        await fixture.headset.reject(.autoPause, .setGet, code: .invalidData)
        let before = await fixture.requestCount()
        await fixture.settle({ controller.setAutoPause(true) }, holding: .autoPause, .setGet)
        #expect(controller.autoPause == false)
        #expect(await fixture.headset.requests(after: before) == [
            FakeRequest(.autoPause, .setGet), FakeRequest(.battery, .get), FakeRequest(.autoPause, .get),
        ])
        await controller.disconnect()
    }

    @Test func confirmedValueWinsOverASnapshotReadBeforeTheAction() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .autoPause: .readWrite, .autoAnswer: .read])
        let controller = fixture.controller
        await fixture.headset.store([0], at: .autoPause)
        await controller.connect()
        let before = await fixture.requestCount()
        await fixture.headset.holdNext(.autoAnswer, .get)
        let poll = Task { await controller.refresh(.full) }
        await fixture.headset.waitUntilHeld()
        controller.setAutoPause(true)
        await until { controller.busy }
        let barrier = Task { await controller.perform { _ in nil } }
        await fixture.headset.release()
        await poll.value
        #expect(await barrier.value)
        #expect(controller.autoPause == true)
        #expect(await fixture.headset.requests(after: before) == [
            FakeRequest(.battery, .get), FakeRequest(.autoPause, .get), FakeRequest(.autoAnswer, .get),
            FakeRequest(.autoPause, .setGet), FakeRequest(.autoPause, .get),
        ])
        await controller.disconnect()
    }

    @Test func audioChangeShowsTheDeviceNormalizedValueAndRefreshesLiveState() async throws {
        let fixture = await HeadsetFixture.withEditableModes()
        let controller = fixture.controller
        await controller.connect()
        #expect(controller.currentMode == 2)
        #expect(controller.audio?.cnc.rawValue == FakeModeTable.configuredCNC)
        let before = await fixture.requestCount()
        await fixture.settle({ controller.setWindBlock(true) }, holding: .modeConfiguration, .setGet)
        #expect(controller.error == nil)
        #expect(controller.audio?.windBlock == true)
        #expect(controller.audio?.cnc == 0)
        #expect(controller.activeMode?.audio == controller.audio)
        #expect(await fixture.headset.requests(after: before) == [
            FakeRequest(.currentMode, .get), FakeRequest(.modeConfiguration, .setGet), FakeRequest(.modeList, .start),
            FakeRequest(.battery, .get), FakeRequest(.currentMode, .get),
        ])
        await controller.disconnect()
    }

    @Test func savingAnInactiveModeAppliesItWithoutARefresh() async throws {
        let fixture = await HeadsetFixture.withEditableModes()
        let controller = fixture.controller
        await controller.connect()
        #expect(!controller.selectableModes.contains { $0.id == 3 })
        let before = await fixture.requestCount()
        let draft = ModeDraft(slot: 3, prompt: .quiet, name: "Y", audio: AudioSettings(cnc: 4))
        #expect(await controller.saveMode(draft))
        let saved = try #require(controller.modes.first { $0.id == 3 })
        #expect(saved.name == "Y")
        #expect(saved.audio?.cnc == 4)
        #expect(controller.selectableModes.contains { $0.id == 3 })
        #expect(controller.audio?.cnc.rawValue == FakeModeTable.configuredCNC)
        #expect(await fixture.headset.requests(after: before) == [
            FakeRequest(.modeConfiguration, .setGet), FakeRequest(.modeList, .start),
        ])
        await controller.disconnect()
    }

    @Test func savingTheActiveModeUpdatesAudioAndRefreshesLiveState() async throws {
        let fixture = await HeadsetFixture.withEditableModes()
        let controller = fixture.controller
        await controller.connect()
        let before = await fixture.requestCount()
        let draft = ModeDraft(slot: 2, prompt: .quiet, name: "X", audio: AudioSettings(cnc: 4))
        #expect(await controller.saveMode(draft))
        #expect(controller.audio?.cnc == 4)
        #expect(controller.activeMode?.audio?.cnc == 4)
        #expect(await fixture.headset.requests(after: before) == [
            FakeRequest(.modeConfiguration, .setGet), FakeRequest(.modeList, .start),
            FakeRequest(.battery, .get), FakeRequest(.currentMode, .get),
        ])
        await controller.disconnect()
    }

    @Test func modeSelectionRefreshesLiveState() async throws {
        let fixture = HeadsetFixture.withModes()
        let controller = fixture.controller
        await controller.connect()
        let before = await fixture.requestCount()
        let selection = try #require(controller.selectMode(2))
        #expect(await selection.value)
        #expect(await fixture.headset.requests(after: before) == [
            FakeRequest(.currentMode, .start), FakeRequest(.currentMode, .get),
            FakeRequest(.battery, .get), FakeRequest(.currentMode, .get),
        ])
        await controller.disconnect()
    }

    @Test func routingAudioRefreshesEverything() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .routing: .write, .sourceDevices: .read])
        let controller = fixture.controller
        await controller.connect()
        let address = try #require(BluetoothAddress(bytes: FakeHeadset.sourceAddress))
        let before = await fixture.requestCount()
        await fixture.settle({ controller.routeAudio(to: address) }, holding: .routing, .start)
        #expect(controller.error == nil)
        #expect(await fixture.headset.requests(after: before) == [
            FakeRequest(.routing, .start), FakeRequest(.battery, .get),
            FakeRequest(.deviceList, .get), FakeRequest(.deviceInfo, .get),
        ])
        await controller.disconnect()
    }
}
