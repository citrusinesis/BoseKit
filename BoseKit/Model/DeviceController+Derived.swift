import BoseKitEngine

extension DeviceController {
    var activeMode: ModeConfiguration? { modes.first { $0.id == shownMode } }

    var freeModeSlot: ModeConfiguration? {
        modes.first { !$0.configured && profile.modePolicy?.editableSlots.contains($0.id) == true }
    }

    var canEditAudio: Bool {
        switch profile.noiseControl {
        case .modeConfiguration: activeMode?.editable == true
        case .unavailable: false
        case .anr, .directCNC, .audioSettings: true
        @unknown default: false
        }
    }

    var canAdjustCNC: Bool {
        switch profile.noiseControl {
        case .unavailable, .anr: false
        case .modeConfiguration: supports(.modes, write: true)
        case .audioSettings: supports(.audioSettings, write: true)
        case .directCNC: supports(.cnc, write: true)
        @unknown default: false
        }
    }

    var hasListeningControls: Bool { shownAudio != nil || cnc != nil || anr != nil }
    var hasPlaybackSettings: Bool { autoPause != nil || autoAnswer != nil || sidetone != nil }
    var hasConnectionSettings: Bool { multipoint != nil || pairing != nil || supports(.routing, write: true) }
}

extension DeviceController {
    var currentModeSelection: UInt8 {
        get { shownMode ?? 0 }
        set { selectMode(newValue) }
    }

    var defaultModeSelection: UInt8 {
        get { shownDefaultMode ?? 0 }
        set { setDefaultMode(newValue) }
    }

    var anrSelection: ANRLevel {
        get { shownANR ?? .off }
        set { setANR(newValue) }
    }

    var spatialAudioSelection: SpatialAudio {
        get { shownAudio?.spatial ?? .off }
        set { setSpatialAudio(newValue) }
    }

    var windBlockEnabled: Bool {
        get { shownAudio?.windBlock ?? false }
        set { setWindBlock(newValue) }
    }

    var ancEnabled: Bool {
        get { shownAudio?.ancEnabled ?? false }
        set { setANCEnabled(newValue) }
    }

    var automaticCNCEnabled: Bool {
        get { shownAudio?.automaticCNC ?? false }
        set { setAutomaticCNC(newValue) }
    }

    var multipointEnabled: Bool {
        get { shownMultipoint ?? false }
        set { setMultipoint(newValue) }
    }

    var autoPauseEnabled: Bool {
        get { shownAutoPause ?? false }
        set { setAutoPause(newValue) }
    }

    var autoAnswerEnabled: Bool {
        get { shownAutoAnswer ?? false }
        set { setAutoAnswer(newValue) }
    }

    var sidetoneSelection: SidetoneLevel {
        get { shownSidetone ?? .off }
        set { setSidetone(newValue) }
    }

    var voicePromptLanguageSelection: VoicePromptLanguage {
        get { shownVoicePrompts?.language ?? .englishUS }
        set { setVoicePromptLanguage(newValue) }
    }

    var shortcutSelection: ButtonAction {
        get { shownShortcut ?? .disabled }
        set { setShortcut(newValue) }
    }
}
