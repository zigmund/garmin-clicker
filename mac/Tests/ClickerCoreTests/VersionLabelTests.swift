import Testing
@testable import ClickerCore

struct VersionLabelTests {
    static let withCommit = "Version %@ (%@)"
    static let versionOnly = "Version %@"

    private func text(_ version: String?, _ commit: String?) -> String {
        VersionLabel.text(version: version, commit: commit, withCommit: Self.withCommit, versionOnly: Self.versionOnly)
    }

    @Test func versionAndCommit() {
        #expect(text("0.0.1", "abc1234") == "Version 0.0.1 (abc1234)")
    }

    @Test func versionOnly() {
        #expect(text("0.0.1", nil) == "Version 0.0.1")
        #expect(text("0.0.1", "") == "Version 0.0.1")
    }

    @Test func nothingIsDev() {
        #expect(text(nil, nil) == "dev")
        #expect(text("", "abc1234") == "dev")
    }
}
