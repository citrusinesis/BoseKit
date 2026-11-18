import Foundation
import BoseKitEngine

extension AppError {
    var message: String {
        switch self {
        case .engine(let error): String(localized: error.title)
        case .unexpected(let description): description
        }
    }
}

extension BoseError {
    var title: LocalizedStringResource {
        switch self {
        case .disconnected: .errorsDisconnected
        case .timeout: .errorsTimeout
        case .transport: .errorsTransport
        case .unsupported: .errorsUnsupported
        case .device: .errorsRejected
        case .verificationFailed: .errorsVerification
        case .invalidPayload, .invalidArgument, .invalidState, .duplicateProduct: .errorsInvalidValue
        }
    }
}

extension ANRLevel {
    var title: LocalizedStringResource {
        switch self {
        case .off: .commonOff
        case .high: .commonHigh
        case .wind: .soundWindReduction
        case .low: .commonLow
        @unknown default: .commonNone
        }
    }
}

extension SidetoneLevel {
    var title: LocalizedStringResource {
        switch self {
        case .off: .commonOff
        case .low: .commonLow
        case .medium: .commonMedium
        case .high: .commonHigh
        @unknown default: .commonNone
        }
    }

    static let displayOrder: [SidetoneLevel] = [.off, .low, .medium, .high]
}

extension SpatialAudio {
    var title: LocalizedStringResource {
        switch self {
        case .off: .commonOff
        case .still: .soundStill
        case .motion: .soundMotion
        @unknown default: .commonNone
        }
    }
}

extension EQBand {
    var title: LocalizedStringResource {
        switch id {
        case 0: .soundBass
        case 1: .soundMidrange
        case 2: .soundTreble
        default: .soundBand(UInt32(id))
        }
    }
}

extension AudioSourceKind {
    var title: LocalizedStringResource {
        switch self {
        case .bluetooth: .deviceBluetooth
        case .wired: .deviceWired
        default: .commonNone
        }
    }

    var systemImage: String { self == .bluetooth ? "antenna.radiowaves.left.and.right" : "cable.connector" }
}

extension BatteryComponent {
    var title: LocalizedStringResource {
        switch self {
        case .right: .deviceRightBattery
        case .left: .deviceLeftBattery
        case .chargingCase: .deviceCaseBattery
        case .overall: .deviceOverallBattery
        default: .deviceBattery(UInt32(rawValue))
        }
    }
}

extension ButtonEvent {
    var title: LocalizedStringResource {
        self == .longPress ? .deviceLongPress : .deviceShortcutAction
    }
}

extension ButtonAction {
    var title: LocalizedStringResource {
        switch self {
        case .voiceAssistant: .deviceVoiceAssistant
        case .noiseControl: .soundNoiseCancellation
        case .batteryLevel: .deviceBatteryLevel
        case .playPause: .devicePlayPause
        case .increaseAmbient: .deviceIncreaseAmbient
        case .decreaseAmbient: .deviceDecreaseAmbient
        case .wakeWord: .deviceWakeWord
        case .switchDevice: .deviceSwitchDevice
        case .conversationMode: .deviceConversationMode
        case .nextTrack: .deviceNextTrack
        case .previousTrack: .devicePreviousTrack
        case .notifications: .deviceNotifications
        case .windBlock: .soundWindBlock
        case .disabled: .deviceDisabled
        case .appAction: .deviceAppAction
        case .spotify: .deviceSpotify
        case .cycleModes: .deviceCycleModes
        case .immersiveAudio: .soundImmersiveAudio
        case .wiredInput: .deviceWiredInput
        case .linkDevices: .deviceLinkDevices
        default: .deviceAction(UInt32(rawValue))
        }
    }
}

extension VoicePromptLanguage {
    var title: LocalizedStringResource {
        switch self {
        case .englishUK: .languageEnglishUK
        case .englishUS: .languageEnglishUS
        case .french: .languageFrench
        case .italian: .languageItalian
        case .german: .languageGerman
        case .spanish: .languageSpanish
        case .spanishMexico: .languageSpanishMexico
        case .portuguese: .languagePortuguese
        case .mandarin: .languageMandarin
        case .korean: .languageKorean
        case .russian: .languageRussian
        case .polish: .languagePolish
        case .hebrew: .languageHebrew
        case .turkish: .languageTurkish
        case .dutch: .languageDutch
        case .japanese: .languageJapanese
        case .cantonese: .languageCantonese
        case .arabic: .languageArabic
        case .swedish: .languageSwedish
        case .danish: .languageDanish
        case .norwegian: .languageNorwegian
        case .finnish: .languageFinnish
        case .hindi: .languageHindi
        default: .languageUnknown(UInt32(rawValue))
        }
    }
}

extension ModeConfiguration {
    var displayName: String {
        if editable, voicePrompt != .none, let promptName = voicePrompt.protocolName {
            return promptName
        }
        if !name.isEmpty && name != "None" { return name }
        return voicePrompt.protocolName ?? String(localized: .modesFallbackName(UInt32(id) + 1))
    }
}

extension ModePrompt {
    var title: String { protocolName ?? String(localized: .modesPromptName(UInt32(rawValue))) }
}
