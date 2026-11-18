import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // The delegate owns the model so discovery starts at launch even when no window is shown (LSUIElement menu bar app).
    let model = BoseAppModel()

    func applicationDidFinishLaunching(_ notification: Notification) { model.start() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
