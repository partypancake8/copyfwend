import SwiftUI

@main
struct cowpyfwendApp: App {
    var body: some Scene {
        MenuBarExtra("cowpyfwend", systemImage: "doc.on.clipboard") {
            Button("Quit cowpyfwend") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
