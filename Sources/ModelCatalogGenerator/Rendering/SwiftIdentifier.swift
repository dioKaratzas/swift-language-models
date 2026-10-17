/// Swift names for catalog values.
enum SwiftIdentifier {
    /// A lower-camel-case member name for a model id.
    ///
    /// Words join in camel case, `:batch` becomes a `Batch` suffix, and adjacent numbers keep an underscore between
    /// them, so `anthropic/claude-opus-5.5` becomes `anthropicClaudeOpus5_5`. A leading `~` is dropped. A name that
    /// starts with a digit or is a keyword is wrapped in backticks.
    static func member(for id: String) -> String {
        var name = ""
        for word in id.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            if name.isEmpty {
                name = word.prefix(1).lowercased() + word.dropFirst()
            } else if name.last?.isNumber == true, word.first?.isNumber == true {
                name += "_" + word
            } else {
                name += word.prefix(1).uppercased() + word.dropFirst()
            }
        }
        return name.first?.isNumber == true || keywords.contains(name) ? "`\(name)`" : name
    }

    /// The case name for an effort word, with `none` spelled `off`.
    static func effortCase(for word: String) -> String {
        word == "none" ? "off" : member(for: word)
    }

    /// The part of an effort set's type name for one of its words, such as `Xhigh` or `Off`.
    static func effortTypeComponent(for word: String) -> String {
        let name = effortCase(for: word).trimmingBackticks
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// The values whose Swift names collide with another value's, sorted, so a render can refuse them.
    ///
    /// - Parameter named: Each value with its Swift name.
    static func clashes(in named: [(name: String, value: String)]) -> [String] {
        Dictionary(grouping: named, by: \.name).values.filter { $0.count > 1 }.flatMap { $0.map(\.value) }.sorted()
    }

    private static let keywords: Set<String> = [
        "as", "associatedtype", "break", "case", "catch", "class", "continue", "default", "defer", "deinit", "do",
        "else", "enum", "extension", "fallthrough", "false", "for", "func", "guard", "if", "import", "in", "init",
        "inout", "internal", "is", "let", "nil", "operator", "private", "protocol", "public", "repeat", "return",
        "self", "static", "struct", "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias",
        "var", "where", "while",
    ]
}

extension String {
    fileprivate var trimmingBackticks: String {
        hasPrefix("`") ? String(dropFirst().dropLast()) : self
    }
}
