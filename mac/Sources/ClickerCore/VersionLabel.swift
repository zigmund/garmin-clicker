import Foundation

/// Text for the version line in the menu.
public enum VersionLabel {
    public static let devText = "dev"

    /// `withCommit` and `versionOnly` are localized format strings taking
    /// `%@` for the version (and the commit, in `withCommit`).
    /// Empty values count as missing; with no version the result is "dev".
    public static func text(version: String?, commit: String?, withCommit: String, versionOnly: String) -> String {
        guard let version = nonEmpty(version) else { return devText }
        if let commit = nonEmpty(commit) {
            return String(format: withCommit, version, commit)
        }
        return String(format: versionOnly, version)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
