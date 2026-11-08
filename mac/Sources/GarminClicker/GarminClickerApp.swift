import AppKit
import SwiftUI

@main
struct GarminClickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: appDelegate.model)
        } label: {
            MenuBarIcon(model: appDelegate.model)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Owns the model so it exists at launch, before the menu is first opened.
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.onLaunch()
    }
}
