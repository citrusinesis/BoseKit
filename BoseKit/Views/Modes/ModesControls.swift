import SwiftUI
import BoseKitEngine

struct ModesControls: View {
    @Bindable var device: DeviceController
    @State private var editorDraft: ModeEditorDraft?
    @State private var pendingDeletion: ModeConfiguration?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(.modesTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let slot = device.freeModeSlot, device.supports(.modes, write: true) {
                    Button(.modesCreate, systemImage: "plus") {
                        editorDraft = ModeEditorDraft(newModeIn: slot)
                    }
                    .buttonStyle(.glass)
                }
            }
            if device.selectableModes.isEmpty {
                ContentUnavailableView(.modesEmptyTitle, systemImage: "waveform",
                                       description: Text(.modesEmptyHelp))
            }
            VStack(spacing: 10) {
                ForEach(device.selectableModes) { mode in
                    ModeRow(device: device, mode: mode,
                            edit: { editorDraft = ModeEditorDraft(editing: mode) },
                            delete: { pendingDeletion = mode })
                }
            }
            if device.favorites != nil {
                SettingsFootnote(.modesFavoritesHelp)
            }
            if device.defaultMode != nil {
                Picker(.modesPowerOn, selection: $device.defaultModeSelection) {
                    ForEach(device.selectableModes) { Text($0.displayName).tag($0.id) }
                }
                .disabled(!device.supports(.defaultMode, write: true))
            }
        }
        .sheet(item: $editorDraft) { ModeEditor(device: device, initial: $0.draft) }
        .confirmationDialog(Text(.modesDeleteConfirmation), isPresented: isConfirmingDeletion,
                            titleVisibility: .visible, presenting: pendingDeletion) { mode in
            Button(.modesDelete, role: .destructive) { device.deleteMode(mode.id) }
        } message: { _ in
            Text(.modesDeleteHelp)
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
