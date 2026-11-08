import ClickerCore
import Foundation

/// Localized strings for the language chosen in the app, independent of the
/// system language, so switching applies immediately without a relaunch.
/// Lookup order: chosen `.lproj` → `en.lproj` → the key itself.
struct L10n {
    let code: String
    private let bundles: [Bundle]

    init(language: AppLanguage, preferred: [String] = Locale.preferredLanguages) {
        code = language.resolve(preferred: preferred)
        bundles = (code == "en" ? ["en"] : [code, "en"])
            .compactMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
            .compactMap(Bundle.init(path:))
    }

    func callAsFunction(_ key: String, _ args: CVarArg...) -> String {
        let format = lookup(key)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: Locale(identifier: code), arguments: args)
    }

    private func lookup(_ key: String) -> String {
        for bundle in bundles {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key { return value }
        }
        return key
    }
}
