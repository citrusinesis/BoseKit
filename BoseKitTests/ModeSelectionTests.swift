import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct ModeSelectionTests {
    @Test func selectedModeShowsImmediatelyAndIsConfirmed() async throws {
        let fixture = HeadsetFixture.withModes()
        let controller = fixture.controller
        await controller.connect()
        #expect(controller.shownMode == 0)
        let selection = try #require(controller.selectMode(2))
        #expect(controller.shownMode == 2)
        #expect(controller.currentMode == 0)
        #expect(await selection.value)
        #expect(controller.shownMode == 2)
        #expect(controller.currentMode == 2)
        #expect(controller.pending.isEmpty)
        #expect(await fixture.headset.currentMode == 2)
        await controller.disconnect()
    }

    @Test func rejectedModeSelectionRollsBack() async throws {
        let fixture = HeadsetFixture.withModes()
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.rejectSelection(of: 2)
        let selection = try #require(controller.selectMode(2))
        #expect(controller.shownMode == 2)
        #expect(await selection.value == false)
        #expect(controller.shownMode == 0)
        #expect(controller.error == .engine(.device(.currentMode, code: .operatorNotSupported, detail: nil)))
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
        #expect(controller.shownMode == 2)
        await fixture.headset.release()
        #expect(await toOne.value)
        #expect(await toTwo.value == false)
        #expect(controller.shownMode == 1)
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
        #expect(controller.shownMode == 2)
        #expect(await fixture.headset.currentMode == 2)
        await controller.disconnect()
    }

    @Test func threeQuickSelectionsShowTheLastOneThroughout() async throws {
        let fixture = HeadsetFixture.withModes()
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.holdNext(.currentMode, .start)
        let toOne = try #require(controller.selectMode(1))
        await fixture.headset.waitUntilHeld()
        let toTwo = try #require(controller.selectMode(2))
        let toThree = try #require(controller.selectMode(3))
        #expect(controller.shownMode == 3)
        await fixture.headset.release()
        #expect(await toOne.value)
        #expect(controller.shownMode == 3)
        #expect(await toTwo.value)
        #expect(controller.shownMode == 3)
        #expect(await toThree.value)
        #expect(controller.shownMode == 3)
        #expect(controller.currentMode == 3)
        #expect(await fixture.headset.currentMode == 3)
        await controller.disconnect()
    }

    @Test func threeQuickSelectionsFallBackToTheLastConfirmedOne() async throws {
        let fixture = HeadsetFixture.withModes()
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.rejectSelection(of: 3)
        await fixture.headset.holdNext(.currentMode, .start)
        let toOne = try #require(controller.selectMode(1))
        await fixture.headset.waitUntilHeld()
        let toTwo = try #require(controller.selectMode(2))
        let toThree = try #require(controller.selectMode(3))
        #expect(controller.shownMode == 3)
        await fixture.headset.release()
        #expect(await toOne.value)
        #expect(await toTwo.value)
        #expect(await toThree.value == false)
        #expect(controller.shownMode == 2)
        #expect(controller.pending.isEmpty)
        #expect(await fixture.headset.currentMode == 2)
        await controller.disconnect()
    }

    @Test func selectedModeShowsItsAudioAndEditabilityImmediately() async throws {
        let fixture = await HeadsetFixture.withEditableModes()
        let controller = fixture.controller
        await controller.connect()
        #expect(controller.shownAudio?.cnc.rawValue == FakeModeTable.configuredCNC)
        #expect(controller.canEditAudio)
        await fixture.headset.holdNext(.currentMode, .start)
        let selection = try #require(controller.selectMode(1))
        #expect(controller.shownMode == 1)
        #expect(controller.activeMode?.id == 1)
        #expect(controller.shownAudio?.cnc == .maximum)
        #expect(!controller.canEditAudio)
        #expect(controller.audio?.cnc.rawValue == FakeModeTable.configuredCNC)
        await fixture.headset.waitUntilHeld()
        await fixture.headset.release()
        #expect(await selection.value)
        #expect(controller.audio?.cnc == .maximum)
        #expect(controller.shownAudio?.cnc == .maximum)
        #expect(!controller.canEditAudio)
        await controller.disconnect()
    }

    @Test func rejectedSelectionReturnsToTheConfirmedModeAndItsAudio() async throws {
        let fixture = await HeadsetFixture.withEditableModes()
        let controller = fixture.controller
        await controller.connect()
        await fixture.headset.rejectSelection(of: 1)
        let selection = try #require(controller.selectMode(1))
        #expect(controller.shownAudio?.cnc == .maximum)
        #expect(await selection.value == false)
        #expect(controller.shownMode == 2)
        #expect(controller.shownAudio?.cnc.rawValue == FakeModeTable.configuredCNC)
        #expect(controller.canEditAudio)
        await controller.disconnect()
    }
}
