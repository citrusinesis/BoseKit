import SwiftUI
import BoseKitEngine

struct DeviceHeader: View {
    @Bindable var model: BoseAppModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "headphones")
                .font(.title2)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if model.devices.count > 1 {
                    Picker(.commonDevice, selection: $model.selectedID) {
                        ForEach(model.devices) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                } else if let device = model.selected {
                    Text(device.name).font(.headline)
                } else {
                    Text(.commonAppName).font(.headline)
                }
                subtitle
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let percent = model.selected?.battery?.percentage {
                BatteryBadge(percent: percent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var subtitle: Text {
        if let name = model.selected?.profile.name { Text(name) } else { Text(.menuTagline) }
    }
}

private struct BatteryBadge: View {
    let percent: UInt8

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: percent < 20 ? "battery.25percent" : "battery.100percent")
            Text(.deviceBatteryPercentage(UInt32(percent)))
                .monospacedDigit()
                .font(.caption)
        }
        .accessibilityElement(children: .combine)
    }
}
