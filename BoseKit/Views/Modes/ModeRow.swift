import SwiftUI
import BoseKitEngine

struct ModeRow: View {
    let device: DeviceController
    let mode: ModeConfiguration
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        let isCurrent = device.currentMode == mode.id
        HStack(spacing: 12) {
            Button {
                device.selectMode(mode.id)
            } label: {
                HStack {
                    Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode.displayName).fontWeight(.medium)
                        Text(mode.editable ? L10n.Modes.custom : L10n.Modes.preset)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!device.supports(.currentMode, write: true))
            if let favorites = device.favorites {
                FavoriteButton(device: device, mode: mode, isFavorite: favorites.slots.contains(mode.id))
            }
            if mode.editable, device.supports(.modes, write: true) {
                Menu {
                    Button(L10n.Common.edit, systemImage: "pencil", action: edit)
                    Button(L10n.Common.delete, systemImage: "trash", role: .destructive, action: delete)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel(L10n.Modes.manage(mode.displayName))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isCurrent ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.035),
                    in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isCurrent ? Color.accentColor.opacity(0.35) : .clear, lineWidth: 1)
        }
        .buttonStyle(.borderless)
    }
}

private struct FavoriteButton: View {
    let device: DeviceController
    let mode: ModeConfiguration
    let isFavorite: Bool

    var body: some View {
        Button {
            device.setFavorite(mode.id, !isFavorite)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
        }
        .accessibilityLabel(L10n.Modes.favorite(mode.displayName))
        .accessibilityValue(Text(isFavorite ? L10n.Common.selected : L10n.Common.notSelected))
        .disabled(!device.supports(.favorites, write: true))
    }
}

#Preview("Mode rows") {
    if let profile = try? DeviceRegistry.standard().profile(productID: 0x4066) {
        let device = DeviceController(id: "preview", name: "QC Ultra", profile: profile)
        VStack(spacing: 10) {
            ModeRow(device: device, mode: ModeConfiguration(
                id: 0, prompt: 1, name: "Quiet", editable: false, configured: true,
                favorite: true, audio: AudioSettings(cnc: 0), rawPayload: []
            ), edit: {}, delete: {})
            ModeRow(device: device, mode: ModeConfiguration(
                id: 3, prompt: 11, name: "Work", editable: true, configured: true,
                favorite: true, audio: AudioSettings(cnc: 5), rawPayload: []
            ), edit: {}, delete: {})
        }
        .padding(20)
        .frame(width: 420)
    }
}
