public enum AppLanguage: String, CaseIterable, Sendable, Identifiable {
    case system, en, ru

    public static let supported: [String] = ["en", "ru"]

    public var id: String { rawValue }

    public var titleKey: String {
        switch self {
        case .system: "language.system"
        case .en: "language.en"
        case .ru: "language.ru"
        }
    }

    /// The `.lproj` code to use for this setting.
    public func resolve(preferred: [String]) -> String {
        switch self {
        case .en: return "en"
        case .ru: return "ru"
        case .system:
            for tag in preferred {
                let prefix = tag.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)?.lowercased() ?? ""
                if Self.supported.contains(prefix) { return prefix }
            }
            return "en"
        }
    }
}
