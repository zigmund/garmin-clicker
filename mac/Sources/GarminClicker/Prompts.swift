import AppKit

/// The app's own windows (the first-run alert, the pairing window): floating,
/// visible over other apps' fullscreen spaces (presentations), and the app
/// hides when the last of them closes. The menu is an `NSMenu`, so none open
/// means no app window is visible.
@MainActor enum AppWindows {
    private static var shownCount = 0

    /// Configures and shows a new window, activating the app. Pair every call
    /// with one `closed()` when the window goes away.
    static func show(_ window: NSWindow) {
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.center()
        shownCount += 1
        bringToFront(window)
    }

    static func bringToFront(_ window: NSWindow) {
        if NSApp.isHidden { NSApp.unhide(nil) }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Closing the last window hides the app: an `LSUIElement` app stays
    /// active after its window goes away, so the next synthesized key press
    /// would reach us instead of the presentation. Hiding hands activation
    /// back to the previously active app.
    static func closed() {
        shownCount -= 1
        if shownCount == 0 { NSApp.hide(nil) }
    }
}

/// Prompts are non-modal (no `runModal`): a nested modal run loop would
/// stall the main queue, i.e. all main-actor work and Bluetooth callbacks.
/// The caller must keep the returned object alive while it is shown.
enum Prompts {
    /// First-run question. `completion` gets true for "Start Pairing",
    /// false for "Not Now".
    @MainActor static func askStartPairing(_ l: L10n, completion: @escaping (Bool) -> Void) -> AnyObject {
        FloatingAlert(title: l("prompt.firstRun.title"), message: l("prompt.firstRun.message"),
                      confirm: l("prompt.firstRun.yes"), cancel: l("prompt.firstRun.no"),
                      completion: completion)
    }
}

/// `NSAlert` shown as a free-standing `AppWindows` window.
/// Return = confirm, Esc = cancel.
@MainActor private final class FloatingAlert: NSObject {
    private let alert = NSAlert()
    private var completion: ((Bool) -> Void)?

    init(title: String, message: String, confirm: String, cancel: String,
         completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()

        alert.messageText = title
        alert.informativeText = message
        let confirmButton = alert.addButton(withTitle: confirm)
        confirmButton.target = self
        confirmButton.action = #selector(confirmPressed)
        let cancelButton = alert.addButton(withTitle: cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed)

        alert.layout()
        AppWindows.show(alert.window)
    }

    @objc private func confirmPressed() { answer(true) }
    @objc private func cancelPressed() { answer(false) }

    private func answer(_ confirmed: Bool) {
        guard let completion else { return }
        self.completion = nil
        // The completion usually drops the owner's last reference to us;
        // stay alive until this button action returns. It runs before the
        // window closes, so a window it opens (pairing) keeps the app from
        // hiding in between.
        withExtendedLifetime(self) {
            completion(confirmed)
            alert.window.orderOut(nil)
            AppWindows.closed()
        }
    }
}
