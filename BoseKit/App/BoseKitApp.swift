import SwiftUI
import BoseKitEngine

@main
struct BoseKitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: BoseAppModel

    init() {
        let appModel = BoseAppModel()
        _model = State(initialValue: appModel)
        delegate.model = appModel
    }

    var body: some Scene {
        Window(L10n.Common.appName, id: ControlWindow.id) {
            ControlWindow(model: model)
        }
        .defaultSize(width: 420, height: 650)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)

        MenuBarExtra(isInserted: $model.menuInserted) {
            MenuBarControls(model: model)
        } label: {
            MenuBarLabel(batteryPercentage: model.menuBatteryPercentage)
        }
        .menuBarExtraStyle(.window)
    }
}
