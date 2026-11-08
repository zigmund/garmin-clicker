import Testing
@testable import ClickerCore

struct KeySchemeTests {
    @Test func arrowsMapping() {
        #expect(KeyScheme.arrows.keystroke(for: .next) == Keystroke(keyCode: 124, shift: false))
        #expect(KeyScheme.arrows.keystroke(for: .previous) == Keystroke(keyCode: 123, shift: false))
    }
    @Test func pageMapping() {
        #expect(KeyScheme.pageUpDown.keystroke(for: .next) == Keystroke(keyCode: 121, shift: false))
        #expect(KeyScheme.pageUpDown.keystroke(for: .previous) == Keystroke(keyCode: 116, shift: false))
    }
    @Test func spaceMapping() {
        #expect(KeyScheme.space.keystroke(for: .next) == Keystroke(keyCode: 49, shift: false))
        #expect(KeyScheme.space.keystroke(for: .previous) == Keystroke(keyCode: 49, shift: true))
    }
    @Test func defaultIsArrows() { #expect(KeyScheme.default == .arrows) }
    @Test func rawValuesStable() {
        #expect(KeyScheme.allCases.map(\.rawValue) == ["arrows", "pageUpDown", "space"])
    }
}
