import SwiftUI
import BoseKitEngine

struct VoicePromptSettings: View {
    @Bindable var device: DeviceController
    @State private var confirmingToggle = false

    var body: some View {
        if let prompts = device.voicePrompts {
            SettingsToggle(title: L10n.Device.voicePrompts, isOn: enabled(prompts.enabled))
            Divider()
            SettingsPicker(title: L10n.Device.promptLanguage, selection: $device.voicePromptLanguageSelection) {
                ForEach(languages(including: prompts.language), id: \.self) { Text($0.title).tag($0) }
            }
            .confirmationDialog(L10n.Device.voicePromptConfirmation, isPresented: $confirmingToggle,
                                titleVisibility: .visible) {
                Button(L10n.Common.change) { device.setVoicePromptsEnabled(!prompts.enabled) }
            } message: {
                Text(L10n.Device.voicePromptWarning)
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
