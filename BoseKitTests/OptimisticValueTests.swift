import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct OptimisticValueTests {
    @Test func toggleShowsTheRequestedValueWhileTheWriteIsHeld() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .autoPause: .readWrite])
        let controller = fixture.controller
        await fixture.headset.store([0], at: .autoPause)
        await controller.connect()
        await fixture.headset.holdNext(.autoPause, .setGet)
        controller.setAutoPause(true)
        #expect(controller.autoPauseEnabled)
        #expect(controller.autoPause == false)
        await fixture.headset.waitUntilHeld()
        #expect(controller.shownAutoPause == true)
        let barrier = Task { await controller.perform { _ in nil } }
        await fixture.headset.release()
        #expect(await barrier.value)
        #expect(controller.autoPause == true)
        #expect(controller.shownAutoPause == true)
        #expect(controller.pending.isEmpty)
        #expect(controller.error == nil)
        await controller.disconnect()
    }

    @Test func rejectedToggleReturnsToTheConfirmedValueAndShowsTheError() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .autoPause: .readWrite])
        let controller = fixture.controller
        await fixture.headset.store([0], at: .autoPause)
        await controller.connect()
        await fixture.headset.reject(.autoPause, .setGet, code: .invalidData)
        await fixture.headset.holdNext(.autoPause, .setGet)
        controller.setAutoPause(true)
        #expect(controller.shownAutoPause == true)
        await fixture.headset.waitUntilHeld()
        let barrier = Task { await controller.perform { _ in nil } }
        await fixture.headset.release()
        #expect(await barrier.value)
        #expect(controller.shownAutoPause == false)
        #expect(controller.pending.isEmpty)
        #expect(controller.error == .engine(.device(.autoPause, code: .invalidData, detail: nil)))
        await controller.disconnect()
    }

    @Test func queuedChangesToOneValueShowTheLatestRequestThroughout() async throws {
        let fixture = try await Self.sidetoneFixture()
        let controller = fixture.controller
        await fixture.headset.holdNext(.sidetone, .setGet)
        controller.setSidetone(.high)
        await fixture.headset.waitUntilHeld()
        controller.setSidetone(.low)
        #expect(controller.shownSidetone == .low)
        await fixture.headset.holdNext(.sidetone, .setGet)
        await fixture.headset.release()
        await fixture.headset.waitUntilHeld()
        #expect(controller.sidetone == .high)
        #expect(controller.shownSidetone == .low)
        let barrier = Task { await controller.perform { _ in nil } }
        await fixture.headset.release()
        #expect(await barrier.value)
        #expect(controller.sidetone == .low)
        #expect(controller.shownSidetone == .low)
        #expect(controller.pending.isEmpty)
        await controller.disconnect()
    }

    @Test func failedLaterChangeFallsBackToTheEarlierConfirmation() async throws {
        let fixture = try await Self.sidetoneFixture()
        let controller = fixture.controller
        await fixture.headset.holdNext(.sidetone, .setGet)
        controller.setSidetone(.high)
        await fixture.headset.waitUntilHeld()
        controller.setSidetone(.low)
        await fixture.headset.holdNext(.sidetone, .setGet)
        await fixture.headset.release()
        await fixture.headset.waitUntilHeld()
        #expect(controller.shownSidetone == .low)
        await fixture.headset.reject(.sidetone, .setGet)
        let barrier = Task { await controller.perform { _ in nil } }
        await fixture.headset.release()
        #expect(await barrier.value)
        #expect(controller.sidetone == .high)
        #expect(controller.shownSidetone == .high)
        #expect(controller.pending.isEmpty)
        #expect(controller.error == .engine(.device(.sidetone, code: .operatorNotSupported, detail: nil)))
        await controller.disconnect()
    }

    @Test func pollFinishingWhileAValueIsPendingKeepsTheShownValue() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .autoPause: .readWrite, .autoAnswer: .read])
        let controller = fixture.controller
        await fixture.headset.store([0], at: .autoPause)
        await controller.connect()
        await fixture.headset.holdNext(.autoAnswer, .get)
        let poll = Task { await controller.refresh(.full) }
        await fixture.headset.waitUntilHeld()
        controller.setAutoPause(true)
        await fixture.headset.holdNext(.autoPause, .setGet)
        await fixture.headset.release()
        await poll.value
        #expect(controller.autoPause == false)
        #expect(controller.shownAutoPause == true)
        await fixture.headset.waitUntilHeld()
        let barrier = Task { await controller.perform { _ in nil } }
        await fixture.headset.release()
        #expect(await barrier.value)
        #expect(controller.autoPause == true)
        #expect(controller.shownAutoPause == true)
        await controller.disconnect()
    }

    @Test func windBlockShowsTheForcedLevelAndSettlesOnTheDeviceValue() async throws {
        let fixture = await HeadsetFixture.withEditableModes()
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.holdNext(.modeConfiguration, .setGet)
        controller.setWindBlock(true)
        #expect(controller.shownAudio?.windBlock == true)
        #expect(controller.shownAudio?.cnc == .minimum)
        #expect(controller.audio?.windBlock == false)
        #expect(controller.audio?.cnc.rawValue == FakeModeTable.configuredCNC)
        await fixture.headset.waitUntilHeld()
        let enabling = Task { await controller.perform { _ in nil } }
        await fixture.headset.release()
        #expect(await enabling.value)
        #expect(controller.audio?.windBlock == true)
        #expect(controller.audio?.cnc == .minimum)
        #expect(controller.shownAudio == controller.audio)

        await fixture.headset.holdNext(.modeConfiguration, .setGet)
        controller.setWindBlock(false)
        #expect(controller.shownAudio?.windBlock == false)
        #expect(controller.shownAudio?.cnc == .minimum)
        await fixture.headset.waitUntilHeld()
        let disabling = Task { await controller.perform { _ in nil } }
        await fixture.headset.release()
        #expect(await disabling.value)
        #expect(controller.error == nil)
        #expect(controller.shownAudio?.windBlock == false)
        #expect(controller.shownAudio?.cnc.rawValue == FakeModeTable.configuredCNC)
        #expect(controller.pending.isEmpty)
        await controller.disconnect()
    }

    @Test func pendingAudioFieldsSettleIndependently() async throws {
        let fixture = await HeadsetFixture.withEditableModes()
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.reject(.modeConfiguration, .setGet)
        await fixture.headset.holdNext(.modeConfiguration, .setGet)
        controller.setWindBlock(true)
        await fixture.headset.waitUntilHeld()
        controller.setCNC(3)
        #expect(controller.shownAudio?.windBlock == true)
        await fixture.headset.holdNext(.modeConfiguration, .setGet)
        await fixture.headset.release()
        await fixture.headset.waitUntilHeld()
        #expect(controller.shownAudio?.windBlock == false)
        #expect(controller.shownAudio?.cnc == 3)
        let barrier = Task { await controller.perform { _ in nil } }
        await fixture.headset.release()
        #expect(await barrier.value)
        #expect(controller.pending.isEmpty)
        #expect(controller.shownAudio?.cnc.rawValue == FakeModeTable.configuredCNC)
        await controller.disconnect()
    }

    @Test func disconnectClearsPendingValues() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .autoPause: .readWrite])
        let controller = fixture.controller
        await fixture.headset.store([0], at: .autoPause)
        await controller.connect()
        await fixture.headset.holdNext(.autoPause, .setGet)
        controller.setAutoPause(true)
        await fixture.headset.waitUntilHeld()
        let barrier = Task { await controller.perform { _ in nil } }
        #expect(controller.shownAutoPause == true)
        await controller.disconnect()
        #expect(controller.pending.isEmpty)
        #expect(controller.shownAutoPause == false)
        #expect(await barrier.value == false)
        #expect(controller.pending.isEmpty)
    }

    @Test func excludedActionsDoNotSetPendingValues() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .name: .readWrite, .pairing: .readWrite,
                                                .routing: .write, .voicePrompts: .readWrite],
                                     voicePromptToggleHasSideEffect: true)
        let controller = fixture.controller
        await fixture.headset.store([0x21], at: .voicePrompts)
        await controller.connect()
        let address = try #require(BluetoothAddress(bytes: FakeHeadset.sourceAddress))
        let name = controller.name
        controller.rename(to: "Renamed")
        controller.setPairing(true)
        controller.routeAudio(to: address)
        controller.setVoicePromptsEnabled(false)
        #expect(controller.pending.isEmpty)
        #expect(controller.name == name)
        #expect(controller.shownVoicePrompts?.enabled == true)
        await controller.perform { _ in nil }
        await controller.disconnect()
    }

    @Test func voicePromptSwitchWithoutSideEffectIsOptimistic() async throws {
        let fixture = HeadsetFixture(features: [.battery: .read, .voicePrompts: .readWrite])
        let controller = fixture.controller
        await fixture.headset.store([0x21], at: .voicePrompts)
        await controller.connect()
        await fixture.headset.holdNext(.voicePrompts, .get)
        controller.setVoicePromptsEnabled(false)
        #expect(controller.shownVoicePrompts?.enabled == false)
        #expect(controller.voicePrompts?.enabled == true)
        await fixture.headset.waitUntilHeld()
        let barrier = Task { await controller.perform { _ in nil } }
        await fixture.headset.release()
        #expect(await barrier.value)
        #expect(controller.voicePrompts?.enabled == false)
        #expect(controller.pending.isEmpty)
        await controller.disconnect()
    }

    private static func sidetoneFixture() async throws -> HeadsetFixture {
        let fixture = HeadsetFixture(features: [.battery: .read, .sidetone: .readWrite])
        await fixture.headset.store([1, SidetoneLevel.off.rawValue], at: .sidetone)
        await fixture.controller.connect()
        #expect(fixture.controller.sidetone == .off)
        return fixture
    }
}
