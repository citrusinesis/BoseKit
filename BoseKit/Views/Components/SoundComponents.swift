import SwiftUI
import BoseKitEngine

struct SpatialAudioPicker: View {
    @Binding var selection: SpatialAudio

    var body: some View {
        SettingsPicker(title: .soundImmersiveAudio, selection: $selection) {
            ForEach(SpatialAudio.allCases, id: \.self) { Text($0.title).tag($0) }
        }
    }
}

struct NoiseControlRangeLabels: View {
    var body: some View {
        HStack {
            Text(.soundMaximumCancellation)
            Spacer()
            Text(.soundMaximumAwareness)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
