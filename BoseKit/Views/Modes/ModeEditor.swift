import SwiftUI
import BoseKitEngine

struct ModeEditor: View {
    let device: DeviceController
    @State private var draft: ModeDraft
    @State private var saving = false
    @State private var saveFailed = false
    @Environment(\.dismiss) private var dismiss

    init(device: DeviceController, initial: ModeDraft) {
        self.device = device
        _draft = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(.modesCustom)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSection(title: .commonName) {
                        SettingsPicker(title: .modesVoicePromptName, selection: $draft.prompt) {
                            ForEach(promptChoices, id: \.self) { Text($0.title).tag($0) }
                        }
                    }
                    SettingsSection(title: .commonSound) {
                        ModeAudioEditor(profile: device.profile, audio: $draft.audio,
                                        allowsSpatialAudio: device.supports(.spatialAudio, write: true),
                                        allowsWindBlock: device.supports(.windBlock, write: true))
                    }
                    if saveFailed, let error = device.error {
                        Text(error.message).font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(20)
            }
            Divider()
            HStack(spacing: 12) {
                if saving { ProgressView().controlSize(.small) }
                Spacer()
                Button(.commonCancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(.commonSave, action: save)
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
        ModePrompt.named.contains(draft.prompt) ? ModePrompt.named : ModePrompt.named + [draft.prompt]
    }

    private func save() {
        var toSave = draft
        if let name = draft.prompt.protocolName.flatMap(ModeName.init(rawValue:)) { toSave.name = name }
        saving = true
        saveFailed = false
        Task {
            let success = await device.saveMode(toSave)
            saving = false
            saveFailed = !success
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
            Text(.soundAmbientLevel(UInt32(audio.cnc.rawValue)))
                .monospacedDigit()
            Slider(value: $audio.cncLevel, in: CNCLevel.sliderRange, step: 1)
                .accessibilityLabel(.soundAmbient)
                .disabled(cncLocked)
            NoiseControlRangeLabels()
        }
        if allowsSpatialAudio {
            Divider()
            SpatialAudioPicker(selection: $audio.spatial)
        }
        if allowsWindBlock {
            Divider()
            SettingsToggle(title: .soundWindBlock, isOn: $audio.windBlock)
        }
        if profile.modePolicy?.allowsCustomAutoCNC == true {
            SettingsToggle(title: .soundAutomaticAmbient, isOn: $audio.automaticCNC)
        }
        if audio.ancEnabled != nil {
            SettingsToggle(title: .soundNoiseCancellation, isOn: $audio.ancToggle)
        }
    }
}

private extension AudioSettings {
    var cncLevel: Double {
        get { Double(cnc.rawValue) }
        set { cnc = CNCLevel(sliderValue: newValue) }
    }

    var ancToggle: Bool {
        get { ancEnabled ?? false }
        set { ancEnabled = newValue }
    }
}

#Preview("Mode Editor") {
    ModeEditor(
        device: DeviceController(id: "preview", name: "QC Ultra", profile: .lonestarr),
        initial: ModeDraft(slot: 3, prompt: .work, name: "WORK", audio: AudioSettings(cnc: 0))
    )
}
