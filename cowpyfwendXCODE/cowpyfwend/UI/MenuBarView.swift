import AppKit
import SwiftUI

/// Primary menu rendered inside the `MenuBarExtra`.
///
/// Observes `AppController` via `@EnvironmentObject` and delegates all actions back to it.
/// No business logic lives here — the view is a pure reflection of controller state.
struct MenuBarView: View {

    @EnvironmentObject private var controller: AppController

    var body: some View {
        // 1. App title — non-interactive label
        Text("cowpyfwend")

        Divider()

        // 3. Enabled / Disabled toggle
        Toggle("Enabled", isOn: Binding(
            get: { controller.isEnabled },
            set: { _ in controller.toggleEnabled() }
        ))

        Divider()

        // 5. Launch at Login
        Toggle("Launch at Login", isOn: Binding(
            get: { controller.launchAtLoginEnabled },
            set: { _ in controller.toggleLaunchAtLogin() }
        ))

        Divider()

        // 7. History count — non-interactive
        Text("History: \(controller.historyCount) entries")

        // 8. Clear History
        Button("Clear History") {
            controller.clearHistory()
        }

        Divider()

        // 10. Accessibility status
        if controller.accessibilityGranted {
            Text("Accessibility: Granted")
        } else {
            Button("Accessibility: Not Granted") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }

        Divider()

        // 12. Quit
        Button("Quit cowpyfwend") {
            NSApplication.shared.terminate(nil)
        }
    }
}
