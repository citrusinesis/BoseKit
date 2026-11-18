import SwiftUI
import BoseKitEngine

struct VoicePromptSettings: View {
    @Bindable var device: DeviceController
    @State private var confirmingToggle = false

    var body: some View {
        if let prompts = device.voicePrompts {
            SettingsToggle(title: .deviceVoicePrompts, isOn: enabled(prompts.enabled))
            Divider()
            SettingsPicker(title: .devicePromptLanguage, selection: $device.voicePromptLanguageSelection) {
                ForEach(languages(including: prompts.language), id: \.self) { Text($0.title).tag($0) }
            }
            .confirmationDialog(.deviceVoicePromptConfirmation, isPresented: $confirmingToggle,
                                titleVisibility: .visible) {
                Button(.commonChange) { device.setVoicePromptsEnabled(!prompts.enabled) }
            } message: {
                Text(.deviceVoicePromptWarning)
            }
        }
    }

    private func enabled(_ current: Bool) -> Binding<Bool> {
        Binding(get: { current }, set: { newValue in
            if device.profile.voicePromptToggleHasSideEffect {
                confirmingToggle = true
            } else {
                device.setVoicePromptsEnabled(newValue)
            }
        })
    }

    private func languages(including current: VoicePromptLanguage) -> [VoicePromptLanguage] {
        VoicePromptLanguage.known.contains(current) ? VoicePromptLanguage.known : VoicePromptLanguage.known + [current]
    }
}
