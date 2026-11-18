import SwiftUI
import BoseKitEngine

struct ModesControls: View {
    @Bindable var device: DeviceController
    @State private var editorDraft: ModeEditorDraft?
    @State private var pendingDeletion: ModeConfiguration?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.Modes.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let slot = device.freeModeSlot, device.supports(.modes, write: true) {
                    Button(L10n.Modes.create, systemImage: "plus") {
                        editorDraft = ModeEditorDraft(newModeIn: slot)
                    }
                    .buttonStyle(.glass)
                }
            }
            if device.selectableModes.isEmpty {
                ContentUnavailableView(L10n.Modes.emptyTitle, systemImage: "waveform",
                                       description: Text(L10n.Modes.emptyHelp))
            }
            VStack(spacing: 10) {
                ForEach(device.selectableModes) { mode in
                    ModeRow(device: device, mode: mode,
                            edit: { editorDraft = ModeEditorDraft(editing: mode) },
                            delete: { pendingDeletion = mode })
                }
            }
            if device.favorites != nil {
                SettingsFootnote(L10n.Modes.favoritesHelp)
            }
            if device.defaultMode != nil {
                Picker(L10n.Modes.powerOn, selection: $device.defaultModeSelection) {
                    ForEach(device.selectableModes) { Text($0.displayName).tag($0.id) }
                }
                .disabled(!device.supports(.defaultMode, write: true))
            }
        }
        .sheet(item: $editorDraft) { ModeEditor(device: device, initial: $0.draft) }
        .confirmationDialog(Text(L10n.Modes.deleteConfirmation), isPresented: isConfirmingDeletion,
                            titleVisibility: .visible, presenting: pendingDeletion) { mode in
            Button(L10n.Modes.delete, role: .destructive) { device.deleteMode(mode.id) }
        } message: { _ in
            Text(L10n.Modes.deleteHelp)
        }
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }
}

struct ModeEditorDraft: Identifiable {
    let draft: ModeDraft
    var id: UInt8 { draft.slot }

    init(newModeIn slot: ModeConfiguration) {
        let prompt = ModePrompt.work
        draft = ModeDraft(slot: slot.id, voicePrompt: prompt, name: prompt.title,
                          audio: AudioSettings(cnc: 0, ancEnabled: slot.audio?.ancEnabled))
    }

    init?(editing mode: ModeConfiguration) {
        guard let audio = mode.audio else { return nil }
        draft = ModeDraft(slot: mode.id, prompt: mode.prompt, name: mode.name, audio: audio)
    }
}
