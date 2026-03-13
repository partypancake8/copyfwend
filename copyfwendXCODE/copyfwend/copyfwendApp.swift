import SwiftUI

@main
struct copyfwendApp: App {

    @StateObject private var appController = AppController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appController)
        } label: {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.green)
        }
        .menuBarExtraStyle(.menu)
    }
}
