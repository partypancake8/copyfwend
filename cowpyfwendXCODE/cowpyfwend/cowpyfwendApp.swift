import SwiftUI

@main
struct cowpyfwendApp: App {

    private let monitor = ClipboardMonitor()
    private let hotkey = HotkeyEngine()

    init() {
        monitor.onNewEntry = { text in
            print("[ClipboardMonitor] new entry: \(text.prefix(80))")
        }
        monitor.start()

        hotkey.onCycleOlder = { print("[HotkeyEngine] cycle older") }
        hotkey.onCycleNewer = { print("[HotkeyEngine] cycle newer") }
        hotkey.onTapDisabled = { print("[HotkeyEngine] tap disabled — check Accessibility") }
        hotkey.enable()
    }

    var body: some Scene {
        MenuBarExtra("cowpyfwend", systemImage: "doc.on.clipboard") {
            Button("Quit cowpyfwend") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
