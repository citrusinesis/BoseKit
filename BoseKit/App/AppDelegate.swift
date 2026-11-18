import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: BoseAppModel?

    func applicationDidFinishLaunching(_ notification: Notification) { model?.start() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
