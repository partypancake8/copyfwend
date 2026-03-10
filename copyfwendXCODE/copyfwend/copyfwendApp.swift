import SwiftUI

@main
struct copyfwendApp: App {

    @StateObject private var appController = AppController()

    var body: some Scene {
        MenuBarExtra("copyfwend", systemImage: "doc.on.clipboard") {
            MenuBarView()
                .environmentObject(appController)
        }
        .menuBarExtraStyle(.menu)
    }
}
