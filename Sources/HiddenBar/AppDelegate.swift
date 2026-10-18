import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
    }

    /// Relancer l'app (Finder, Spotlight) déplie tout et ramène notre chevron :
    /// seul accès au menu clic droit une fois replié sur macOS 27.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBar?.expand()
        return false
    }
}
