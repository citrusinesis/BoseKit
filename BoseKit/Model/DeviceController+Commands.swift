import BoseKitEngine

extension DeviceController {
    func setCNC(_ level: CNCLevel) { changeAudio { try await $0.setCNC(level) } }
    func setSpatialAudio(_ value: SpatialAudio) { changeAudio { try await $0.setSpatialAudio(value) } }
    func setWindBlock(_ enabled: Bool) { changeAudio { try await $0.setWindBlock(enabled) } }
    func setANCEnabled(_ enabled: Bool) { changeAudio { try await $0.setANCEnabled(enabled) } }
    func setAutomaticCNC(_ enabled: Bool) { changeAudio { try await $0.setAutomaticCNC(enabled) } }

    func setANR(_ level: ANRLevel) {
        send(refreshing: .live) { _ = try await $0.write(BoseFeatures.anr, value: level) }
    }

    func setEqualizer(band: UInt8, to value: Int8) {
        send(refreshing: .live) { _ = try await $0.setEqualizer(band: band, value: value) }
    }

    func resetEqualizer() { send(refreshing: .live) { _ = try await $0.resetEqualizer() } }

    private func changeAudio(_ action: @escaping @MainActor (BoseDevice) async throws -> AudioSettings?) {
        send(refreshing: .live) { device in
            if let audio = try await action(device) { self.applyConfirmedAudio(audio) }
        }
    }

    func saveMode(_ draft: ModeDraft) async -> Bool {
        await perform { _ = try await $0.saveMode(draft) }
    }

    func deleteMode(_ slot: UInt8) { send { try await $0.deleteMode(slot) } }
    func setFavorite(_ slot: UInt8, _ isFavorite: Bool) { send { _ = try await $0.setFavorite(slot, isFavorite) } }
    func setDefaultMode(_ slot: UInt8) { send { _ = try await $0.write(BoseFeatures.defaultMode, value: slot) } }

    func rename(to name: DeviceName) { send { _ = try await $0.write(BoseFeatures.name, value: name) } }
    func setMultipoint(_ enabled: Bool) { send { _ = try await $0.write(BoseFeatures.multipoint, value: enabled) } }
    func setAutoPause(_ enabled: Bool) { send { _ = try await $0.write(BoseFeatures.autoPause, value: enabled) } }
    func setAutoAnswer(_ enabled: Bool) { send { _ = try await $0.write(BoseFeatures.autoAnswer, value: enabled) } }
    func setPairing(_ enabled: Bool) { send { _ = try await $0.write(BoseFeatures.pairing, value: enabled) } }
    func setSidetone(_ level: SidetoneLevel) { send { _ = try await $0.write(BoseFeatures.sidetone, value: level) } }
    func setVoicePromptsEnabled(_ enabled: Bool) { send { _ = try await $0.setVoicePromptsEnabled(enabled) } }
    func setVoicePromptLanguage(_ language: VoicePromptLanguage) {
        send { _ = try await $0.setVoicePromptLanguage(language) }
    }

    func setShortcut(_ action: ButtonAction) {
        guard let assignment = buttons?.assignment else { return }
        let changed = ButtonAssignment(button: assignment.button, event: assignment.event, action: action)
        send { _ = try await $0.write(BoseFeatures.buttons, value: changed) }
    }

    func routeAudio(to address: BluetoothAddress) { send { try await $0.routeAudio(to: address) } }
}
