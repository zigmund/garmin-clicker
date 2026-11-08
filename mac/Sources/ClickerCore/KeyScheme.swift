public enum SlideAction: Equatable, Sendable { case next, previous }

public struct Keystroke: Equatable, Sendable {
    public var keyCode: UInt16
    public var shift: Bool

    public init(keyCode: UInt16, shift: Bool) {
        self.keyCode = keyCode
        self.shift = shift
    }
}

public enum KeyScheme: String, CaseIterable, Sendable, Identifiable {
    case arrows, pageUpDown, space

    public static let `default`: KeyScheme = .arrows

    public var id: String { rawValue }

    public var titleKey: String {
        switch self {
        case .arrows: "keys.arrows"
        case .pageUpDown: "keys.pageUpDown"
        case .space: "keys.space"
        }
    }

    public func keystroke(for action: SlideAction) -> Keystroke {
        switch (self, action) {
        case (.arrows, .next): Keystroke(keyCode: 124, shift: false)
        case (.arrows, .previous): Keystroke(keyCode: 123, shift: false)
        case (.pageUpDown, .next): Keystroke(keyCode: 121, shift: false)
        case (.pageUpDown, .previous): Keystroke(keyCode: 116, shift: false)
        case (.space, .next): Keystroke(keyCode: 49, shift: false)
        case (.space, .previous): Keystroke(keyCode: 49, shift: true)
        }
    }
}
