import SwiftUI

@main
struct cowpyfwendApp: App {

    private let monitor = ClipboardMonitor()

    init() {
        monitor.onNewEntry = { text in
            print("[ClipboardMonitor] new entry: \(text.prefix(80))")
        }
        monitor.start()
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
