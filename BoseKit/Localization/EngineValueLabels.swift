import Foundation
import BoseKitEngine

extension L10n.Errors {
    static func message(for error: any Error) -> String {
        guard let error = error as? BoseError else { return error.localizedDescription }
        let resource: LocalizedStringResource = switch error {
        case .disconnected: disconnected
        case .timeout: timeout
        case .transport: transport
        case .unsupported: unsupported
        case .device: rejected
        case .verificationFailed: verification
        default: invalidValue
        }
        return String(localized: resource)
    }
}

extension ANRLevel {
    var title: LocalizedStringResource {
        switch self {
        case .off: L10n.Common.off
        case .high: L10n.Common.high
        case .wind: L10n.Sound.windReduction
        case .low: L10n.Common.low
        @unknown default: L10n.Common.none
        }
    }
}

extension SidetoneLevel {
    var title: LocalizedStringResource {
        switch self {
        case .off: L10n.Common.off
        case .low: L10n.Common.low
        case .medium: L10n.Common.medium
        case .high: L10n.Common.high
        @unknown default: L10n.Common.none
        }
    }

    static let displayOrder: [SidetoneLevel] = [.off, .low, .medium, .high]
}

extension SpatialAudio {
    var title: LocalizedStringResource {
        switch self {
        case .off: L10n.Common.off
        case .still: L10n.Sound.still
        case .motion: L10n.Sound.motion
        @unknown default: L10n.Common.none
        }
    }
}

extension EQBand {
    var title: LocalizedStringResource {
        switch id {
        case 0: L10n.Sound.bass
        case 1: L10n.Sound.midrange
        case 2: L10n.Sound.treble
        default: L10n.Sound.band(id)
        }
    }
}

extension AudioSourceKind {
    var title: LocalizedStringResource {
        switch self {
        case .bluetooth: L10n.Device.bluetooth
        case .wired: L10n.Device.wired
        default: L10n.Common.none
        }
    }

    var systemImage: String { self == .bluetooth ? "antenna.radiowaves.left.and.right" : "cable.connector" }
}

extension BatteryComponent {
    var title: LocalizedStringResource {
        switch self {
        case .right: L10n.Device.rightBattery
        case .left: L10n.Device.leftBattery
        case .chargingCase: L10n.Device.caseBattery
        case .overall: L10n.Device.overallBattery
        default: L10n.Device.battery(rawValue)
        }
    }
}

extension ButtonEvent {
    var title: LocalizedStringResource {
        self == .longPress ? L10n.Device.longPress : L10n.Device.shortcutAction
    }
}

extension ButtonAction {
    var title: LocalizedStringResource {
        switch self {
        case .voiceAssistant: L10n.Device.voiceAssistant
        case .noiseControl: L10n.Sound.noiseCancellation
        case .batteryLevel: L10n.Device.batteryLevel
        case .playPause: L10n.Device.playPause
        case .increaseAmbient: L10n.Device.increaseAmbient
        case .decreaseAmbient: L10n.Device.decreaseAmbient
        case .wakeWord: L10n.Device.wakeWord
        case .switchDevice: L10n.Device.switchDevice
        case .conversationMode: L10n.Device.conversationMode
        case .nextTrack: L10n.Device.nextTrack
        case .previousTrack: L10n.Device.previousTrack
        case .notifications: L10n.Device.notifications
        case .windBlock: L10n.Sound.windBlock
        case .disabled: L10n.Device.disabled
        case .appAction: L10n.Device.appAction
        case .spotify: L10n.Device.spotify
        case .cycleModes: L10n.Device.cycleModes
        case .immersiveAudio: L10n.Sound.immersiveAudio
        case .wiredInput: L10n.Device.wiredInput
        case .linkDevices: L10n.Device.linkDevices
        default: L10n.Device.action(rawValue)
        }
    }
}

extension VoicePromptLanguage {
    var title: LocalizedStringResource {
        switch self {
        case .englishUK: L10n.Language.englishUK
        case .englishUS: L10n.Language.englishUS
        case .french: L10n.Language.french
        case .italian: L10n.Language.italian
        case .german: L10n.Language.german
        case .spanish: L10n.Language.spanish
        case .spanishMexico: L10n.Language.spanishMexico
        case .portuguese: L10n.Language.portuguese
        case .mandarin: L10n.Language.mandarin
        case .korean: L10n.Language.korean
        case .russian: L10n.Language.russian
        case .polish: L10n.Language.polish
        case .hebrew: L10n.Language.hebrew
        case .turkish: L10n.Language.turkish
        case .dutch: L10n.Language.dutch
        case .japanese: L10n.Language.japanese
        case .cantonese: L10n.Language.cantonese
        case .arabic: L10n.Language.arabic
        case .swedish: L10n.Language.swedish
        case .danish: L10n.Language.danish
        case .norwegian: L10n.Language.norwegian
        case .finnish: L10n.Language.finnish
        case .hindi: L10n.Language.hindi
        default: L10n.Language.unknown(rawValue)
        }
    }
}

extension ModeConfiguration {
    var displayName: String {
        if editable, voicePrompt != .none, let promptName = voicePrompt.protocolName {
            return promptName
        }
        if !name.isEmpty && name != "None" { return name }
        return voicePrompt.protocolName ?? String(localized: L10n.Modes.fallbackName(id + 1))
    }
}

extension ModePrompt {
    var title: String { protocolName ?? String(localized: L10n.Modes.promptName(rawValue)) }
}
