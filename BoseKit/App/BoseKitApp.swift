import SwiftUI

@main
struct BoseKitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    private var model: BoseAppModel { delegate.model }

    var body: some Scene {
        Window(.commonAppName, id: ControlWindow.id) {
            ControlWindow(model: model)
        }
        .defaultSize(width: 420, height: 650)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)

        MenuBarExtra(isInserted: Bindable(model).menuInserted) {
            MenuBarControls(model: model)
        } label: {
            MenuBarLabel(batteryPercentage: model.menuBatteryPercentage)
        }
        .menuBarExtraStyle(.window)
    }
}
