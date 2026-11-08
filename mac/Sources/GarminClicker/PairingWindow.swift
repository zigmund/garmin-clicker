import AppKit
import ClickerCore
import SwiftUI

/// What the pairing window shows.
enum PairingPhase: Equatable {
    /// Pairing mode is on; waiting for a watch to send HELLO.
    case waiting
    /// A watch asks to pair (the controller's pending approval).
    case request(ApprovalRequest)
    /// The user allowed this watch; pairing mode is already off.
    case paired(PairedWatch)
}

/// Non-modal pairing window. Pairing mode lasts while it is open: `onClose`
/// runs whenever it closes, by any means (its buttons, the close button,
/// ⌘W, or `close()`). The owner must keep this object alive while it is shown.
@MainActor final class PairingWindow: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private var onClose: (() -> Void)?

    init(model: AppModel, onClose: @escaping () -> Void) {
        self.onClose = onClose
        let hosting = NSHostingController(rootView: PairingView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        window = CommandWClosableWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        super.init()
        setTitle(model.l10n("pairing.window.title"))
        window.delegate = self
        AppWindows.show(window)
    }

    func setTitle(_ title: String) { window.title = title }

    func bringToFront() { AppWindows.bringToFront(window) }

    func close() { window.close() }

    func windowWillClose(_ notification: Notification) {
        guard let onClose else { return }
        self.onClose = nil
        AppWindows.closed()
        // onClose drops the owner's reference to us.
        withExtendedLifetime(self) { onClose() }
    }
}

/// An `LSUIElement` app shows no main menu, so ⌘W cannot rely on
/// File → Close; handle it here.
private final class CommandWClosableWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

private struct PairingView: View {
    let model: AppModel

    var body: some View {
        let l = model.l10n
        VStack(alignment: .leading, spacing: 12) {
            switch model.pairingPhase {
            case .waiting:
                Text(l("pairing.window.instructions", model.macName))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(l("pairing.window.waiting")).foregroundStyle(.secondary)
                }
                buttons {
                    Button(l("pairing.window.close")) { model.closePairingWindow() }
                        .keyboardShortcut(.cancelAction)
                }
            case let .request(request):
                Text(l("pairing.window.request", request.watch.name))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(l("approval.message"))
                    .fixedSize(horizontal: false, vertical: true)
                if let replacing = request.replacing {
                    Text(l("approval.replaces", replacing.name))
                        .fixedSize(horizontal: false, vertical: true)
                }
                buttons {
                    Button(l("approval.deny")) { model.answerPairingRequest(request, approved: false) }
                        .keyboardShortcut(.cancelAction)
                    Button(l("approval.allow")) { model.answerPairingRequest(request, approved: true) }
                        .keyboardShortcut(.defaultAction)
                }
            case let .paired(watch):
                Text(l("pairing.window.paired", watch.name))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                buttons {
                    Button(l("pairing.window.done")) { model.closePairingWindow() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 380, alignment: .leading)
    }

    private func buttons(@ViewBuilder _ content: () -> some View) -> some View {
        HStack {
            Spacer()
            content()
        }
    }
}
