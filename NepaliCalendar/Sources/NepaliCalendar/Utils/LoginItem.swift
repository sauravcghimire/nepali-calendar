import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` so the rest of the app can treat "launch at
/// login" as a simple boolean toggle. `SMAppService` requires macOS 13+ which
/// matches our deployment target.
///
/// On first app launch we attempt to register once (so Homebrew installs
/// automatically get login-start behaviour), then we never auto-toggle again —
/// the user owns the switch from that point forward via the popover toggle
/// or System Settings → General → Login Items.
final class LoginItem: ObservableObject {
    static let shared = LoginItem()

    private let attemptedAutoEnableKey = "loginItemAutoEnableAttempted"

    @Published private(set) var isEnabled: Bool = false

    private init() {
        self.isEnabled = currentStatus == .enabled
    }

    /// Run once from AppDelegate. Enables launch-at-login the very first time
    /// the app is opened (e.g. right after `brew install`), then leaves user
    /// control alone on subsequent launches.
    func registerIfFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: attemptedAutoEnableKey) else {
            isEnabled = currentStatus == .enabled
            return
        }
        defaults.set(true, forKey: attemptedAutoEnableKey)
        setEnabled(true)
    }

    /// Toggle the login-item registration; updates `isEnabled` to reflect what
    /// macOS actually accepted (the user may have denied in System Settings).
    func setEnabled(_ enable: Bool) {
        let service = SMAppService.mainApp
        do {
            if enable {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            NSLog("[NepaliCalendar] SMAppService \(enable ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
        isEnabled = currentStatus == .enabled
    }

    /// Current macOS-reported registration status for the main app.
    private var currentStatus: SMAppService.Status {
        SMAppService.mainApp.status
    }
}
