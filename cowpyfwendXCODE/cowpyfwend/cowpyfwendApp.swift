import SwiftUI

@main
struct cowpyfwendApp: App {

    @StateObject private var appController = AppController()

    var body: some Scene {
        MenuBarExtra("cowpyfwend", systemImage: "doc.on.clipboard") {
            MenuBarView()
                .environmentObject(appController)
        }
        .menuBarExtraStyle(.menu)
    }
}
