import SwiftUI
import BoseKitEngine

struct SpatialAudioPicker: View {
    @Binding var selection: SpatialAudio

    var body: some View {
        SettingsPicker(title: L10n.Sound.immersiveAudio, selection: $selection) {
            ForEach(SpatialAudio.allCases, id: \.self) { Text($0.title).tag($0) }
        }
    }
}

struct NoiseControlRangeLabels: View {
    var body: some View {
        HStack {
            Text(L10n.Sound.maximumCancellation)
            Spacer()
            Text(L10n.Sound.maximumAwareness)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
