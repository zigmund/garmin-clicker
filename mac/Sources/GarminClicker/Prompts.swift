import AppKit
import ClickerCore

/// An open approval window that can be closed from outside (e.g. the watch
/// disconnected) without counting as an answer.
@MainActor protocol ApprovalPrompt {
    /// Closes the window; the completion handler is not called.
    func dismiss()
}

/// Both prompts are non-modal (no `runModal`): a nested modal run loop would
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

    /// Approval window for a new watch. `completion` gets true for "Allow",
    /// false for "Deny"; it is never called after `dismiss()`.
    @MainActor static func askApproval(_ r: ApprovalRequest, _ l: L10n,
                                       completion: @escaping (Bool) -> Void) -> ApprovalPrompt {
        var message = l("approval.message")
        if let replacing = r.replacing {
            message += "\n\n" + l("approval.replaces", replacing.name)
        }
        return FloatingAlert(title: l("approval.title", r.watch.name), message: message,
                             confirm: l("approval.allow"), cancel: l("approval.deny"),
                             completion: completion)
    }
}

/// `NSAlert` shown as a free-standing floating panel, visible over other
/// apps' fullscreen spaces (presentations), closable programmatically.
/// Return = confirm, Esc = cancel.
@MainActor private final class FloatingAlert: NSObject, ApprovalPrompt {
    /// Alerts on screen. These are the app's only windows (the menu is an
    /// `NSMenu`), so none open means no app window is visible.
    private static var shownCount = 0

    private let alert = NSAlert()
    private var completion: ((Bool) -> Void)?
    private var isShown = false

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
        let window = alert.window
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.center()
        if NSApp.isHidden { NSApp.unhide(nil) }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        isShown = true
        Self.shownCount += 1
    }

    func dismiss() {
        completion = nil
        close()
    }

    @objc private func confirmPressed() { answer(true) }
    @objc private func cancelPressed() { answer(false) }

    private func answer(_ confirmed: Bool) {
        guard let completion else { return }
        self.completion = nil
        close()
        // The completion usually drops the owner's last reference to us;
        // stay alive until this button action returns.
        withExtendedLifetime(self) { completion(confirmed) }
    }

    /// Hides the window. Closing the last one hides the app: an `LSUIElement`
    /// app stays active after its window goes away, so the next synthesized
    /// key press would reach us instead of the presentation. Hiding hands
    /// activation back to the previously active app.
    private func close() {
        guard isShown else { return }
        isShown = false
        alert.window.orderOut(nil)
        Self.shownCount -= 1
        if Self.shownCount == 0 { NSApp.hide(nil) }
    }
}
