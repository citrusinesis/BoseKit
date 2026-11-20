import BoseKitEngine

extension DeviceController {
    var shownMode: UInt8? { currentMode.map(pending.currentMode.shown(over:)) }

    var shownAudio: AudioSettings? {
        guard var shown = shownModeAudio ?? audio else { return nil }
        shown.cnc = pending.cnc.shown(over: shown.cnc)
        shown.spatial = pending.spatialAudio.shown(over: shown.spatial)
        shown.windBlock = pending.windBlock.shown(over: shown.windBlock)
        shown.ancEnabled = shown.ancEnabled.map(pending.ancEnabled.shown(over:))
        shown.automaticCNC = pending.automaticCNC.shown(over: shown.automaticCNC)
        if shown.windBlock && windBlockForcesCNC { shown.cnc = .minimum }
        return shown
    }

    var shownCNC: UInt8? { cnc.map { pending.cnc.value?.rawValue ?? $0.current } }
    var shownANR: ANRLevel? { anr.map(pending.anr.shown(over:)) }
    var shownDefaultMode: UInt8? { defaultMode.map(pending.defaultMode.shown(over:)) }
    var shownMultipoint: Bool? { multipoint.map(pending.multipoint.shown(over:)) }
    var shownAutoPause: Bool? { autoPause.map(pending.autoPause.shown(over:)) }
    var shownAutoAnswer: Bool? { autoAnswer.map(pending.autoAnswer.shown(over:)) }
    var shownSidetone: SidetoneLevel? { sidetone.map(pending.sidetone.shown(over:)) }
    var shownShortcut: ButtonAction? { buttons.map { pending.shortcut.shown(over: $0.assignment.action) } }

    var shownVoicePrompts: VoicePrompts? {
        guard var shown = voicePrompts else { return nil }
        shown.enabled = pending.voicePromptsEnabled.shown(over: shown.enabled)
        shown.language = pending.voicePromptLanguage.shown(over: shown.language)
        return shown
    }

    func isFavorite(_ slot: UInt8) -> Bool? {
        favorites.map { pending.favorites[slot].shown(over: $0.slots.contains(slot)) }
    }

    func shownValue(of band: EQBand) -> Int8 { pending.equalizer[band.id].shown(over: band.value) }

    private var shownModeAudio: AudioSettings? {
        guard pending.currentMode.isPending else { return nil }
        return modes.first { $0.id == shownMode }?.audio
    }

    private var windBlockForcesCNC: Bool {
        profile.noiseControl == .modeConfiguration && profile.modePolicy?.windForcesMaximumANC == true
    }
}
