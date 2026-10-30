import Testing

@testable import ModelCatalogGenerator

@Suite("Swift literals")
struct SwiftLiteralTests {
    @Test(arguments: [(0, "0"), (999, "999"), (1_000, "1_000"), (262_144, "262_144"), (1_000_000, "1_000_000")])
    func `an integer groups its digits in threes`(value: Int, literal: String) {
        #expect(SwiftLiteral.integer(value) == literal)
    }

    @Test func `a string escapes quotes, backslashes and line breaks`() {
        #expect(SwiftLiteral.string("a \"b\" \\ c\nd") == #""a \"b\" \\ c\nd""#)
    }

    @Test(arguments: [
        ("a\u{0}b", #""a\u{0}b""#),
        ("a\u{2028}b\u{2029}c\u{85}d", #""a\u{2028}b\u{2029}c\u{85}d""#),
        ("safe\u{202E}evil", #""safe\u{202E}evil""#),
        ("a\u{7F}b", #""a\u{7F}b""#),
    ])
    func `a string escapes every character that doesn't print`(value: String, literal: String) {
        #expect(SwiftLiteral.string(value) == literal)
    }

    @Test func `a string keeps printable text outside ASCII`() {
        #expect(SwiftLiteral.string("Café 🚀") == #""Café 🚀""#)
    }

    @Test func `a day becomes a date at midnight UTC`() {
        #expect(SwiftLiteral.date("2026-12-31") == "Date(timeIntervalSince1970: 1_798_675_200)")
    }
}
