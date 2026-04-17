import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory = menu-bar-only, no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)
        statusBar = StatusBarController()

        // First-run bootstrap: opt the user into launch-at-login so the menu
        // bar icon comes back automatically after a reboot. Idempotent —
        // subsequent launches respect whatever the user has since chosen.
        LoginItem.shared.registerIfFirstLaunch()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
}
