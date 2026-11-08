import SwiftUI

@main
struct GarminClickerApp: App {
    var body: some Scene {
        MenuBarExtra("Garmin Clicker", systemImage: "applewatch") {
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
