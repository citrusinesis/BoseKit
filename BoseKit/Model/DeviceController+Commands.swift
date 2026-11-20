import BoseKitEngine

extension DeviceController {
    @discardableResult
    func selectMode(_ slot: UInt8) -> Task<Bool, Never>? {
        guard connected, shownMode != slot else { return nil }
        return send(slot, pending: \.currentMode, refreshing: .live) { device in
            try await device.selectMode(slot)
            return .currentMode(slot)
        }
    }

    func setCNC(_ level: CNCLevel) {
        guard profile.noiseControl == .directCNC else {
            changeAudio(level, pending: \.cnc) { try await $0.setCNC(level) }
            return
        }
        send(level, pending: \.cnc, refreshing: .live) { .cnc(try await $0.write(BoseFeatures.cnc, value: level)) }
    }

    func setSpatialAudio(_ value: SpatialAudio) {
        changeAudio(value, pending: \.spatialAudio) { try await $0.setSpatialAudio(value) }
    }

    func setWindBlock(_ enabled: Bool) {
        changeAudio(enabled, pending: \.windBlock) { try await $0.setWindBlock(enabled) }
    }

    func setANCEnabled(_ enabled: Bool) {
        changeAudio(enabled, pending: \.ancEnabled) { try await $0.setANCEnabled(enabled) }
    }

    func setAutomaticCNC(_ enabled: Bool) {
        changeAudio(enabled, pending: \.automaticCNC) { try await $0.setAutomaticCNC(enabled) }
    }

    func setANR(_ level: ANRLevel) {
        send(level, pending: \.anr) { .anr(try await $0.write(BoseFeatures.anr, value: level)) }
    }

    func setEqualizer(band: UInt8, to value: Int8) {
        send(value, pending: \.equalizer[band]) { .equalizer(try await $0.setEqualizer(band: band, value: value)) }
    }

    func resetEqualizer() {
        let tickets = equalizer.map { pending.request(0, at: \.equalizer[$0.id]) }
        send(pending: tickets) { .equalizer(try await $0.resetEqualizer()) }
    }

    private func changeAudio<Value>(_ value: Value,
                                    pending field: ReferenceWritableKeyPath<PendingChanges, PendingValue<Value>>,
                                    _ action: @escaping @MainActor (BoseDevice) async throws -> AudioSettings?) {
        send(value, pending: field, refreshing: .live) { try await action($0).map(ConfirmedChange.audio) }
    }

    func saveMode(_ draft: ModeDraft) async -> Bool {
        await perform(refreshing: draft.slot == shownMode ? .live : nil) { .mode(try await $0.saveMode(draft)) }
    }

    func deleteMode(_ slot: UInt8) {
        send(refreshing: .full) { device in
            try await device.deleteMode(slot)
            return nil
        }
    }

    func setFavorite(_ slot: UInt8, _ isFavorite: Bool) {
        send(isFavorite, pending: \.favorites[slot]) { .favorites(try await $0.setFavorite(slot, isFavorite)) }
    }

    func setDefaultMode(_ slot: UInt8) {
        send(slot, pending: \.defaultMode) { .defaultMode(try await $0.write(BoseFeatures.defaultMode, value: slot)) }
    }

    func rename(to name: DeviceName) { send { .name(try await $0.write(BoseFeatures.name, value: name)) } }

    func setMultipoint(_ enabled: Bool) {
        send(enabled, pending: \.multipoint, refreshing: .full) {
            .multipoint(try await $0.write(BoseFeatures.multipoint, value: enabled))
        }
    }

    func setAutoPause(_ enabled: Bool) {
        send(enabled, pending: \.autoPause) { .autoPause(try await $0.write(BoseFeatures.autoPause, value: enabled)) }
    }

    func setAutoAnswer(_ enabled: Bool) {
        send(enabled, pending: \.autoAnswer) {
            .autoAnswer(try await $0.write(BoseFeatures.autoAnswer, value: enabled))
        }
    }

    func setPairing(_ enabled: Bool) { send { .pairing(try await $0.write(BoseFeatures.pairing, value: enabled)) } }

    func setSidetone(_ level: SidetoneLevel) {
        send(level, pending: \.sidetone) { .sidetone(try await $0.write(BoseFeatures.sidetone, value: level)) }
    }

    func setVoicePromptsEnabled(_ enabled: Bool) {
        let tickets = profile.voicePromptToggleHasSideEffect
            ? [] : [pending.request(enabled, at: \.voicePromptsEnabled)]
        send(pending: tickets) { .voicePrompts(try await $0.setVoicePromptsEnabled(enabled)) }
    }

    func setVoicePromptLanguage(_ language: VoicePromptLanguage) {
        send(language, pending: \.voicePromptLanguage) {
            .voicePrompts(try await $0.setVoicePromptLanguage(language))
        }
    }

    func setShortcut(_ action: ButtonAction) {
        guard let assignment = buttons?.assignment else { return }
        let changed = ButtonAssignment(button: assignment.button, event: assignment.event, action: action)
        send(action, pending: \.shortcut) { .buttons(try await $0.write(BoseFeatures.buttons, value: changed)) }
    }

    func routeAudio(to address: BluetoothAddress) {
        send(refreshing: .full) { device in
            try await device.routeAudio(to: address)
            return nil
        }
    }
}
