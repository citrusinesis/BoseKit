import SwiftUI
import BoseKitEngine

struct PlaybackSettings: View {
    @Bindable var device: DeviceController

    var body: some View {
        SettingsSection(title: .commonSound) {
            if device.autoPause != nil {
                SettingsToggle(title: .deviceAutoPause, isOn: $device.autoPauseEnabled)
                    .disabled(!device.supports(.autoPause, write: true))
            }
            if device.autoAnswer != nil {
                if device.autoPause != nil { Divider() }
                SettingsToggle(title: .deviceAutoAnswer, isOn: $device.autoAnswerEnabled)
                    .disabled(!device.supports(.autoAnswer, write: true))
            }
            if device.sidetone != nil {
                if device.autoPause != nil || device.autoAnswer != nil { Divider() }
                SettingsPicker(title: .deviceSelfVoice, selection: $device.sidetoneSelection) {
                    ForEach(SidetoneLevel.displayOrder, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(!device.supports(.sidetone, write: true))
            }
        }
    }
}
