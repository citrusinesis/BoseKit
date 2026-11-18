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

extension CNCLevel {
    static let sliderRange = Double(minimum.rawValue)...Double(maximum.rawValue)

    init(sliderValue: Double) {
        let clamped = min(max(sliderValue.rounded(), Self.sliderRange.lowerBound), Self.sliderRange.upperBound)
        guard let level = Self(rawValue: UInt8(clamped)) else { preconditionFailure("Slider range exceeds CNC levels") }
        self = level
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
