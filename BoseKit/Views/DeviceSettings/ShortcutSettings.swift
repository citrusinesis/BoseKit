import SwiftUI
import BoseKitEngine

struct ShortcutSettings: View {
    @Bindable var device: DeviceController

    var body: some View {
        if let buttons = device.buttons {
            SettingsPicker(title: buttons.assignment.event.title, selection: $device.shortcutSelection) {
                ForEach(buttons.selectableActions, id: \.self) { Text($0.title).tag($0) }
            }
            .disabled(!device.supports(.buttons, write: true))
        }
    }
}
