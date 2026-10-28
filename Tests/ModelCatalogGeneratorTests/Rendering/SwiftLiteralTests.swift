import Testing

@testable import ModelCatalogGenerator

@Suite("Swift literals")
struct SwiftLiteralTests {
    @Test(arguments: [(0, "0"), (999, "999"), (1_000, "1_000"), (262_144, "262_144"), (1_000_000, "1_000_000")])
    func `an integer groups its digits in threes`(value: Int, literal: String) {
        #expect(SwiftLiteral.integer(value) == literal)
    }

    @Test(arguments: [
        ("0.000003", "Decimal(sign: .plus, exponent: -6, significand: 3)"),
        ("0.0000015", "Decimal(sign: .plus, exponent: -7, significand: 15)"),
        ("15", "Decimal(sign: .plus, exponent: 0, significand: 15)"),
        ("0", "Decimal(sign: .plus, exponent: 0, significand: 0)"),
    ])
    func `a decimal text becomes an exact Decimal`(text: String, literal: String) {
        #expect(SwiftLiteral.decimal(text) == literal)
    }

    @Test(arguments: ["-1", "1e-6", "", ".5", "1.2.3"])
    func `text that isn't a plain decimal gives nil`(text: String) {
        #expect(SwiftLiteral.decimal(text) == nil)
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

    @Test(arguments: [(0, ".seconds(0)"), (130, ".seconds(5_400)"), (1_600, ".seconds(57_600)"), (2_400, ".seconds(86_400)")])
    func `a clock time becomes the duration after midnight`(clockTime: Int, literal: String) {
        #expect(SwiftLiteral.duration(clockTime: clockTime) == literal)
    }

    @Test(arguments: [-5, 160, 2_401, 2_500])
    func `a number that isn't a clock time gives nil`(clockTime: Int) {
        #expect(SwiftLiteral.duration(clockTime: clockTime) == nil)
    }

    @Test func `a day becomes a date at midnight UTC`() {
        #expect(SwiftLiteral.date("2026-12-31") == "Date(timeIntervalSince1970: 1_798_675_200)")
    }
}
