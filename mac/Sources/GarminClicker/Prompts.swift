import AppKit
import ClickerCore

/// An open approval window that can be closed from outside (e.g. the watch
/// disconnected) without counting as an answer.
@MainActor protocol ApprovalPrompt {
    /// Closes the window; the completion handler is not called.
    func dismiss()
}

enum Prompts {
    /// First-run question. Modal; returns true for "Start Pairing".
    @MainActor static func askStartPairing(_ l: L10n) -> Bool {
        let alert = NSAlert()
        alert.messageText = l("prompt.firstRun.title")
        alert.informativeText = l("prompt.firstRun.message")
        alert.addButton(withTitle: l("prompt.firstRun.yes"))
        alert.addButton(withTitle: l("prompt.firstRun.no")).keyEquivalent = "\u{1b}"
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Non-modal approval window for a new watch. `completion` gets true for
    /// "Allow", false for "Deny"; it is never called after `dismiss()`.
    /// The caller must keep the returned prompt alive while it is shown.
    @MainActor static func askApproval(_ r: ApprovalRequest, _ l: L10n,
                                       completion: @escaping (Bool) -> Void) -> ApprovalPrompt {
        AlertApprovalPrompt(request: r, l10n: l, completion: completion)
    }
}

/// `NSAlert` shown as a free-standing floating panel instead of `runModal`,
/// so the run loop (and Bluetooth callbacks) keep going and the window can be
/// closed programmatically.
@MainActor private final class AlertApprovalPrompt: NSObject, ApprovalPrompt {
    private let alert = NSAlert()
    private var completion: ((Bool) -> Void)?

    init(request: ApprovalRequest, l10n l: L10n, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()

        alert.messageText = l("approval.title", request.watch.name)
        var info = l("approval.message")
        if let replacing = request.replacing {
            info += "\n\n" + l("approval.replaces", replacing.name)
        }
        alert.informativeText = info

        let allow = alert.addButton(withTitle: l("approval.allow"))
        allow.target = self
        allow.action = #selector(allowPressed)
        let deny = alert.addButton(withTitle: l("approval.deny"))
        deny.keyEquivalent = "\u{1b}"
        deny.target = self
        deny.action = #selector(denyPressed)

        alert.layout()
        let window = alert.window
        window.level = .floating
        window.hidesOnDeactivate = false
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        completion = nil
        alert.window.orderOut(nil)
    }

    @objc private func allowPressed() { answer(true) }
    @objc private func denyPressed() { answer(false) }

    private func answer(_ approved: Bool) {
        guard let completion else { return }
        self.completion = nil
        alert.window.orderOut(nil)
        completion(approved)
    }
}
