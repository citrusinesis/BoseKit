import SwiftUI
import BoseKitEngine

struct EqualizerControls: View {
    let device: DeviceController

    var body: some View {
        let editable = device.supports(.equalizer, write: true)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(device.equalizer) { band in
                    VerticalValueSlider(title: band.title,
                                        value: Double(band.value),
                                        range: Double(band.range.lowerBound)...Double(band.range.upperBound),
                                        revision: device.refreshRevision,
                                        editingChanged: device.setEditing) {
                        device.setEqualizer(band: band.id, to: Int8($0))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Button(.soundResetEqualizer) { device.resetEqualizer() }
        }
        .disabled(!editable)
    }
}
