import SwiftUI
import BoseKitEngine

struct ModeEditor: View {
    let device: DeviceController
    @State private var draft: ModeDraft
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss

    init(device: DeviceController, initial: ModeDraft) {
        self.device = device
        _draft = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(L10n.Modes.custom)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSection(title: L10n.Common.name) {
                        SettingsPicker(title: L10n.Modes.voicePromptName, selection: $draft.voicePrompt) {
                            ForEach(promptChoices, id: \.self) { Text($0.title).tag($0) }
                        }
                    }
                    SettingsSection(title: L10n.Common.sound) {
                        ModeAudioEditor(profile: device.profile, audio: $draft.audio,
                                        allowsSpatialAudio: device.supports(.spatialAudio, write: true),
                                        allowsWindBlock: device.supports(.windBlock, write: true))
                    }
                    if let error = device.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(20)
            }
            Divider()
            HStack(spacing: 12) {
                if saving { ProgressView().controlSize(.small) }
                Spacer()
                Button(L10n.Common.cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.Common.save, action: save)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 420, height: 540)
        .settingsContentStyle()
        .disabled(saving || device.busy)
        .interactiveDismissDisabled(saving)
        .onAppear { device.setEditing(true) }
        .onDisappear { device.setEditing(false) }
    }

    private var promptChoices: [ModePrompt] {
        ModePrompt.named.contains(draft.voicePrompt) ? ModePrompt.named : ModePrompt.named + [draft.voicePrompt]
    }

    private func save() {
        var toSave = draft
        if let name = draft.voicePrompt.protocolName { toSave.name = name }
        saving = true
        Task {
            let success = await device.saveMode(toSave)
            saving = false
            if success { dismiss() }
        }
    }
}

private struct ModeAudioEditor: View {
    let profile: DeviceProfile
    @Binding var audio: AudioSettings
    let allowsSpatialAudio: Bool
    let allowsWindBlock: Bool

    var body: some View {
        let cncLocked = audio.windBlock && profile.modePolicy?.windForcesMaximumANC == true
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Sound.ambientLevel(audio.cnc))
                .monospacedDigit()
            Slider(value: $audio.cncLevel, in: 0...10, step: 1)
                .accessibilityLabel(L10n.Sound.ambient)
                .disabled(cncLocked)
            NoiseControlRangeLabels()
        }
        if allowsSpatialAudio {
            Divider()
            SpatialAudioPicker(selection: $audio.spatial)
        }
        if allowsWindBlock {
            Divider()
            SettingsToggle(title: L10n.Sound.windBlock, isOn: $audio.windBlock)
        }
        if profile.modePolicy?.allowsCustomAutoCNC == true {
            SettingsToggle(title: L10n.Sound.automaticAmbient, isOn: $audio.automaticCNC)
        }
        if audio.ancEnabled != nil {
            SettingsToggle(title: L10n.Sound.noiseCancellation, isOn: $audio.ancToggle)
        }
    }
}

private extension AudioSettings {
    var cncLevel: Double {
        get { Double(cnc) }
        set { cnc = UInt8(newValue.rounded()) }
    }

    var ancToggle: Bool {
        get { ancEnabled ?? false }
        set { ancEnabled = newValue }
    }
}

private extension ModeDraft {
    var voicePrompt: ModePrompt {
        get { ModePrompt(rawValue: prompt) }
        set { prompt = newValue.rawValue }
    }
}

#Preview("Mode Editor") {
    if let profile = try? DeviceRegistry.standard().profile(productID: 0x4066) {
        ModeEditor(
            device: DeviceController(id: "preview", name: "QC Ultra", profile: profile),
            initial: ModeDraft(slot: 3, voicePrompt: .work, name: "WORK", audio: AudioSettings(cnc: 0))
        )
    }
}
