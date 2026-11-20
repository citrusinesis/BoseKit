import BoseKitEngine

extension DeviceController {
    func setCNC(_ level: CNCLevel) { changeAudio { try await $0.setCNC(level) } }
    func setSpatialAudio(_ value: SpatialAudio) { changeAudio { try await $0.setSpatialAudio(value) } }
    func setWindBlock(_ enabled: Bool) { changeAudio { try await $0.setWindBlock(enabled) } }
    func setANCEnabled(_ enabled: Bool) { changeAudio { try await $0.setANCEnabled(enabled) } }
    func setAutomaticCNC(_ enabled: Bool) { changeAudio { try await $0.setAutomaticCNC(enabled) } }

    func setANR(_ level: ANRLevel) { send { .anr(try await $0.write(BoseFeatures.anr, value: level)) } }

    func setEqualizer(band: UInt8, to value: Int8) {
        send { .equalizer(try await $0.setEqualizer(band: band, value: value)) }
    }

    func resetEqualizer() { send { .equalizer(try await $0.resetEqualizer()) } }

    private func changeAudio(_ action: @escaping @MainActor (BoseDevice) async throws -> AudioSettings?) {
        send(refreshing: .live) { try await action($0).map(ConfirmedChange.audio) }
    }

    func saveMode(_ draft: ModeDraft) async -> Bool {
        await perform(refreshing: draft.slot == currentMode ? .live : nil) { .mode(try await $0.saveMode(draft)) }
    }

    func deleteMode(_ slot: UInt8) {
        send(refreshing: .full) { device in
            try await device.deleteMode(slot)
            return nil
        }
    }

    func setFavorite(_ slot: UInt8, _ isFavorite: Bool) {
        send { .favorites(try await $0.setFavorite(slot, isFavorite)) }
    }

    func setDefaultMode(_ slot: UInt8) {
        send { .defaultMode(try await $0.write(BoseFeatures.defaultMode, value: slot)) }
    }

    func rename(to name: DeviceName) { send { .name(try await $0.write(BoseFeatures.name, value: name)) } }

    func setMultipoint(_ enabled: Bool) {
        send(refreshing: .full) { .multipoint(try await $0.write(BoseFeatures.multipoint, value: enabled)) }
    }

    func setAutoPause(_ enabled: Bool) {
        send { .autoPause(try await $0.write(BoseFeatures.autoPause, value: enabled)) }
    }

    func setAutoAnswer(_ enabled: Bool) {
        send { .autoAnswer(try await $0.write(BoseFeatures.autoAnswer, value: enabled)) }
    }

    func setPairing(_ enabled: Bool) { send { .pairing(try await $0.write(BoseFeatures.pairing, value: enabled)) } }

    func setSidetone(_ level: SidetoneLevel) {
        send { .sidetone(try await $0.write(BoseFeatures.sidetone, value: level)) }
    }

    func setVoicePromptsEnabled(_ enabled: Bool) {
        send { .voicePrompts(try await $0.setVoicePromptsEnabled(enabled)) }
    }

    func setVoicePromptLanguage(_ language: VoicePromptLanguage) {
        send { .voicePrompts(try await $0.setVoicePromptLanguage(language)) }
    }

    func setShortcut(_ action: ButtonAction) {
        guard let assignment = buttons?.assignment else { return }
        let changed = ButtonAssignment(button: assignment.button, event: assignment.event, action: action)
        send { .buttons(try await $0.write(BoseFeatures.buttons, value: changed)) }
    }

    func routeAudio(to address: BluetoothAddress) {
        send(refreshing: .full) { device in
            try await device.routeAudio(to: address)
            return nil
        }
    }
}
