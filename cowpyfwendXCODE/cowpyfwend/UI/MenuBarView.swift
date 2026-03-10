import AppKit
import SwiftUI

/// Primary menu rendered inside the `MenuBarExtra`.
///
/// Observes `AppController` via `@EnvironmentObject` and delegates all actions back to it.
/// No business logic lives here — the view is a pure reflection of controller state.
///
/// Stage-8 note: `launchAtLogin` is a local placeholder `@State` until
/// `LaunchAtLoginManager` (SMAppService) is wired in Stage 8.
struct MenuBarView: View {

    @EnvironmentObject private var controller: AppController

    /// Placeholder — replaced by a real `LaunchAtLoginManager` binding in Stage 8.
    @State private var launchAtLogin: Bool = false

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

        // 5. Launch at Login — placeholder; fully wired in Stage 8
        Toggle("Launch at Login", isOn: $launchAtLogin)
            .disabled(true)

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
