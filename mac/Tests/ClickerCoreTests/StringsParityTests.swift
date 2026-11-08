import Foundation
import Testing
@testable import ClickerCore

struct StringsParityTests {
    static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources")

    static func load(_ lang: String, _ table: String) throws -> [String: String] {
        let url = resources.appendingPathComponent("\(lang).lproj/\(table).strings")
        let dict = NSDictionary(contentsOf: url) as? [String: String]
        return try #require(dict, "cannot parse \(url.path)")
    }

    static let tableKeys = [
        "status.connected", "status.waiting", "status.notPaired", "status.pairing", "status.paused",
        "status.bluetoothOff", "status.bluetoothUnauthorized", "status.noInputPermission",
        "menu.paired", "menu.pairWatch", "menu.forgetWatch", "menu.broadcast",
        "menu.keys", "keys.arrows", "keys.pageUpDown", "keys.space", "menu.language",
        "language.system", "language.en", "language.ru", "menu.launchAtLogin",
        "menu.grantPermission", "menu.quit",
        "prompt.firstRun.title", "prompt.firstRun.message", "prompt.firstRun.yes", "prompt.firstRun.no",
        "pairing.window.title", "pairing.window.instructions", "pairing.window.waiting",
        "pairing.window.request", "pairing.window.paired", "pairing.window.close", "pairing.window.done",
        "approval.message", "approval.replaces", "approval.allow", "approval.deny",
    ]

    @Test(arguments: ["Localizable", "InfoPlist"])
    func keySetsMatch(table: String) throws {
        let en = try Self.load("en", table), ru = try Self.load("ru", table)
        #expect(Set(en.keys) == Set(ru.keys))
        #expect(!en.isEmpty)
    }

    @Test func localizableKeySetsMatch() throws {
        #expect(Set(try Self.load("en", "Localizable").keys) == Set(try Self.load("ru", "Localizable").keys))
    }

    @Test func allCodeKeysExist() throws {
        let en = try Self.load("en", "Localizable")
        var keys = Self.tableKeys
        keys += KeyScheme.allCases.map(\.titleKey)
        keys += AppLanguage.allCases.map(\.titleKey)
        let statuses: [MenuBarStatus] = [.connected(name: "x"), .waiting, .notPaired, .pairing, .paused,
                                         .bluetoothOff, .bluetoothUnauthorized, .noInputPermission]
        keys += statuses.map(\.titleKey)
        for key in keys { #expect(en[key] != nil, "missing key \(key)") }
        #expect(Set(en.keys) == Set(Self.tableKeys))
    }

    @Test(arguments: ["Localizable", "InfoPlist"])
    func formatArgumentsMatch(table: String) throws {
        let en = try Self.load("en", table), ru = try Self.load("ru", table)
        for (key, value) in en {
            let ruValue = try #require(ru[key])
            #expect(value.components(separatedBy: "%@").count == ruValue.components(separatedBy: "%@").count, "\(key)")
        }
    }

    @Test func infoPlistHasBluetoothDescription() throws {
        for lang in ["en", "ru"] {
            #expect(try Self.load(lang, "InfoPlist")["NSBluetoothAlwaysUsageDescription"] != nil)
        }
    }
}
