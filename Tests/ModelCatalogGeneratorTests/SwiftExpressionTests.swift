import Testing

@testable import ModelCatalogGenerator

@Suite("Swift expressions")
struct SwiftExpressionTests {
    private static let longText = SwiftLiteral.string(String(repeating: "x", count: 130))

    @Test func `an expression that fits stays on one line and leaves out arguments without a value`() {
        let expression = SwiftExpression.call("f", ["a": .array([.atom("1"), .atom("2")]), "b": nil])

        #expect(expression.lines(indent: "    ", suffix: ",") == ["    f(a: [1, 2]),"])
    }

    @Test func `an expression that doesn't fit breaks one level at a time`() {
        let expression = SwiftExpression.call("f", ["a": .array([.atom("1"), .atom("2")]), "b": .atom(Self.longText)])

        #expect(expression.lines(indent: "") == ["f(", "    a: [1, 2],", "    b: \(Self.longText)", ")"])
    }

    @Test func `a broken array puts a comma after every element`() {
        let expression = SwiftExpression.array([.atom(Self.longText), .atom("2")])

        #expect(expression.lines(indent: "", prefix: "let a = ") == ["let a = [", "    \(Self.longText),", "    2,", "]"])
    }

    @Test func `a call can break even when it fits`() {
        #expect(SwiftExpression.call("f", ["a": .atom("1")]).lines(indent: "", breaks: true) == ["f(", "    a: 1", ")"])
    }

    @Test func `a doc comment wraps to the line length`() {
        let words = Array(repeating: "word", count: 40).joined(separator: " ")

        let lines = SourceText.documentation(words, indent: "    ")

        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.hasPrefix("    /// ") && $0.count < SourceText.lineLength })
    }
}
