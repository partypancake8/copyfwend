import ServiceManagement

/// Stateless wrapper around `SMAppService.mainApp` for launch-at-login registration.
///
/// Uses SMAppService (macOS 13+), which stores registration in the system
/// launch daemon database — no Login Items plist manipulation required.
///
/// `register()` and `unregister()` both log on failure but do not throw;
/// callers should re-read `isEnabled` after calling either to get ground truth.
enum LaunchAtLoginManager {

    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers the app with the system to launch at login.
    /// No-ops if already registered.
    static func register() {
        guard !isEnabled else { return }
        do {
            try SMAppService.mainApp.register()
            print("[LaunchAtLoginManager] registered for launch at login")
        } catch {
            print("[LaunchAtLoginManager] register failed: \(error.localizedDescription)")
        }
    }

    /// Removes the app's launch-at-login registration.
    /// No-ops if not currently registered.
    static func unregister() {
        guard isEnabled else { return }
        do {
            try SMAppService.mainApp.unregister()
            print("[LaunchAtLoginManager] unregistered from launch at login")
        } catch {
            print("[LaunchAtLoginManager] unregister failed: \(error.localizedDescription)")
        }
    }

    /// Convenience: toggles registration state.
    static func toggle() {
        if isEnabled { unregister() } else { register() }
    }
}
