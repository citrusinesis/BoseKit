import Testing
import Foundation
import BoseKitEngine
@testable import BoseKit

@MainActor
struct EngineValueLabelTests {
    @Test func semanticResourcesResolveInBothLanguages() {
        #expect(resolve(.menuTitle, in: "en") == "Menu Bar")
        #expect(resolve(.menuTitle, in: "ko") == "메뉴 막대")
    }

    @Test func windBlockLockGetsItsOwnMessage() {
        let title = BoseError.invalidState(.windBlockLocksCNC).title
        #expect(resolve(title, in: "en") == "Turn off Wind Block to change the ambient sound level.")
        #expect(resolve(title, in: "ko") == "주변 소리 수준을 변경하려면 바람 소리 감소를 끄세요.")
        #expect(resolve(title, in: "en") != resolve(BoseError.invalidArgument("CNC").title, in: "en"))
    }

    @Test(arguments: [
        BoseError.InvalidState.windBlockLocksCNC, .modeNotConfigured, .noFallbackPreset,
        .currentModeUnavailable, .currentModeHasNoAudioSettings,
    ])
    func everyInvalidStateHasADistinctMessage(_ state: BoseError.InvalidState) {
        let others = [BoseError.InvalidState.windBlockLocksCNC, .modeNotConfigured, .noFallbackPreset,
                      .currentModeUnavailable, .currentModeHasNoAudioSettings].filter { $0 != state }
        let message = resolve(state.title, in: "en")
        #expect(!message.isEmpty)
        #expect(others.allSatisfy { resolve($0.title, in: "en") != message })
        #expect(resolve(state.title, in: "ko") != message)
    }

    @Test func groupedEngineErrorsKeepTheirGeneralMessages() {
        #expect(resolve(BoseError.unsupported(.feature(.anr)).title, in: "en")
            == resolve(.errorsUnsupported, in: "en"))
        #expect(resolve(BoseError.verificationFailed(.feature(.anr)).title, in: "en")
            == resolve(.errorsVerification, in: "en"))
        #expect(resolve(BoseError.verificationFailed(.currentModeNotApplied).title, in: "en")
            == resolve(.errorsModeNotApplied, in: "en"))
        #expect(resolve(BoseError.unsupported(.nonEditableModeSlot(1)).title, in: "en")
            == resolve(.errorsModeNotEditable, in: "en"))
    }

    @Test(arguments: [
        (BMAPErrorCode?.some(.functionBlockNotSupported), LocalizedStringResource.errorsUnsupported),
        (.functionNotSupported, .errorsUnsupported),
        (.operatorNotSupported, .errorsUnsupported),
        (.invalidData, .errorsInvalidValue),
        (.invalidState, .errorsUnavailableInCurrentState),
        (.busy, .errorsTemporarilyUnavailable),
        (.dataUnavailable, .errorsTemporarilyUnavailable),
        (.runtime, .errorsTemporarilyUnavailable),
        (.timeout, .errorsTemporarilyUnavailable),
        (.unknown, .errorsRejected),
        (.length, .errorsRejected),
        (.deviceNotFound, .errorsRejected),
        (.functionBlockSpecific, .errorsRejected),
        (BMAPErrorCode(rawValue: 0x42), .errorsRejected),
        (nil, .errorsRejected),
    ])
    func deviceErrorMessagesFollowTheErrorCode(_ code: BMAPErrorCode?, _ expected: LocalizedStringResource) {
        let title = BoseError.device(.anr, code: code, detail: nil).title
        #expect(resolve(title, in: "en") == resolve(expected, in: "en"))
        #expect(resolve(title, in: "ko") == resolve(expected, in: "ko"))
    }

    @Test func deviceErrorMessagesAreDistinctInBothLanguages() {
        let titles: [LocalizedStringResource] = [.errorsRejected, .errorsUnsupported, .errorsInvalidValue,
                                                 .errorsUnavailableInCurrentState, .errorsTemporarilyUnavailable]
        for language in ["en", "ko"] {
            let messages = titles.map { resolve($0, in: language) }
            #expect(Set(messages).count == titles.count)
            #expect(messages.allSatisfy { !$0.isEmpty && !$0.hasPrefix("errors.") })
        }
        #expect(resolve(.errorsTemporarilyUnavailable, in: "ko") != resolve(.errorsTemporarilyUnavailable, in: "en"))
        #expect(resolve(.errorsUnavailableInCurrentState, in: "ko")
            != resolve(.errorsUnavailableInCurrentState, in: "en"))
    }

    @Test func customModeNamesFollowVoicePromptsAndPreserveUnknownNames() {
        let custom = ModeConfiguration(id: 3, prompt: .music, name: "Old custom name",
            editable: true, configured: true, favorite: false, audio: AudioSettings(cnc: 5), rawPayload: [])
        let unknown = ModeConfiguration(id: 4, prompt: ModePrompt(rawValue: 999), name: "Future mode",
            editable: true, configured: true, favorite: false, audio: AudioSettings(cnc: 5), rawPayload: [])
        let preset = ModeConfiguration(id: 0, prompt: .quiet, name: "Quiet", editable: false,
            configured: true, favorite: true, audio: AudioSettings(cnc: 0), rawPayload: [])
        #expect(custom.displayName == "MUSIC")
        #expect(unknown.displayName == "Future mode")
        #expect(preset.displayName == "Quiet")
    }

    private func resolve(_ resource: LocalizedStringResource, in language: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }
}
