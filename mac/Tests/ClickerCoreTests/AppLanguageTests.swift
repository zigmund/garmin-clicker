import Testing
@testable import ClickerCore

struct AppLanguageTests {
    @Test func explicitLanguageWins() {
        #expect(AppLanguage.ru.resolve(preferred: ["en-US"]) == "ru")
        #expect(AppLanguage.en.resolve(preferred: ["ru"]) == "en")
    }
    @Test func systemPicksRegionalRussian() {
        #expect(AppLanguage.system.resolve(preferred: ["ru-KZ", "en"]) == "ru")
    }
    @Test func systemSkipsUnsupported() {
        #expect(AppLanguage.system.resolve(preferred: ["de-DE", "ru"]) == "ru")
    }
    @Test func systemFallsBackToEnglish() {
        #expect(AppLanguage.system.resolve(preferred: ["de"]) == "en")
        #expect(AppLanguage.system.resolve(preferred: []) == "en")
    }
    @Test func titleKeys() {
        #expect(AppLanguage.allCases.map(\.titleKey) == ["language.system", "language.en", "language.ru"])
    }
}
