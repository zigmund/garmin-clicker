import ClickerCore
import CoreGraphics

/// Posts a key press (down + up) to the system HID event stream.
enum KeySender {
    static func send(_ k: Keystroke) {
        let source = CGEventSource(stateID: .hidSystemState)
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: k.keyCode, keyDown: keyDown) else {
                continue
            }
            event.flags = k.shift ? .maskShift : []
            event.post(tap: .cghidEventTap)
        }
    }
}
