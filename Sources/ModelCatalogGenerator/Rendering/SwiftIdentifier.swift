/// A Swift name made from catalog text, such as a model's static member or an effort word's member.
///
/// The name is kept without backticks, so a suffix such as `Entry` joins the name itself. Its ``description`` spells
/// it the way code must: in backticks when it starts with a digit or is a keyword.
struct SwiftIdentifier: Hashable, CustomStringConvertible {
    /// The names of `Optional`'s cases, which no static member of a vocabulary or model type can take: where an
    /// optional value is expected, `.none` means `Optional.none` rather than the member, and `.some` reads as
    /// `Optional.some`.
    static let optionalCaseNames: Set<String> = ["none", "some"]

    /// The name without backticks.
    let name: String

    var description: String {
        name.first?.isNumber == true || Self.keywords.contains(name) ? "`\(name)`" : name
    }

    /// The name followed by a suffix, such as `Entry`.
    func appending(_ suffix: String) -> SwiftIdentifier {
        SwiftIdentifier(name: name + suffix)
    }

    /// A lower-camel-case member name for a model id or a vocabulary word.
    ///
    /// ASCII letters and digits form words, and every other character separates them. Words join in camel case, and
    /// adjacent numbers keep an underscore between them, so `anthropic/claude-opus-5.5` becomes
    /// `anthropicClaudeOpus5_5` and a `:free` variant gets a `Free` suffix. Text without ASCII letters or digits gets
    /// an empty name, which ``check(_:reserved:kind:)`` refuses.
    static func member(for text: String) -> SwiftIdentifier {
        var name = ""
        for word in text.split(whereSeparator: { !($0.isASCII && ($0.isLetter || $0.isNumber)) }) {
            if name.isEmpty {
                name = word.prefix(1).lowercased() + word.dropFirst()
            } else if name.last?.isNumber == true, word.first?.isNumber == true {
                name += "_" + word
            } else {
                name += word.capitalizingFirstLetter
            }
        }
        return SwiftIdentifier(name: name)
    }

    /// The member name for an effort word, with `none` spelled `off`.
    static func effortMember(for word: String) -> SwiftIdentifier {
        word == "none" ? SwiftIdentifier(name: "off") : member(for: word)
    }

    /// The upper-camel-case type name for a model id, such as `AnthropicClaudeOpus5_5` for
    /// `anthropic/claude-opus-5.5`.
    static func type(for text: String) -> SwiftIdentifier {
        SwiftIdentifier(name: member(for: text).name.capitalizingFirstLetter)
    }

    /// Checks that every value in a scope gets a name of its own that the scope doesn't already declare.
    ///
    /// - Parameters:
    ///   - named: Each value with its name. A value can appear more than once, with different names.
    ///   - reserved: The names the scope already declares.
    ///   - kind: What the values are, such as `OpenRouter models`, for the error message.
    /// - Throws: ``GeneratorError/invalidCatalog(_:)`` naming the values that get no name, a reserved name or the
    ///   same name as another value.
    static func check(
        _ named: [(identifier: SwiftIdentifier, value: String)],
        reserved: Set<String> = [],
        kind: String
    ) throws(GeneratorError) {
        func list(_ values: [String]) -> String { Set(values).sorted().joined(separator: ", ") }

        let unnamed = named.filter(\.identifier.name.isEmpty).map(\.value)
        guard unnamed.isEmpty else { throw .invalidCatalog("These \(kind) get no Swift name: \(list(unnamed)).") }
        let taken = named.filter { reserved.contains($0.identifier.name) }.map(\.value)
        guard taken.isEmpty else { throw .invalidCatalog("These \(kind) get a Swift name that's taken: \(list(taken)).") }
        let clashes = Dictionary(grouping: named, by: \.identifier).values.map { $0.map(\.value) }.filter { Set($0).count > 1 }
        guard clashes.isEmpty else {
            throw .invalidCatalog("These \(kind) get the same Swift name: \(list(clashes.flatMap(\.self))).")
        }
    }

    private static let keywords: Set<String> = [
        "as", "associatedtype", "break", "case", "catch", "class", "continue", "default", "defer", "deinit", "do",
        "else", "enum", "extension", "fallthrough", "false", "fileprivate", "for", "func", "guard", "if", "import", "in",
        "init", "inout", "internal", "is", "let", "nil", "operator", "private", "protocol", "public", "repeat",
        "rethrows", "return", "self", "static", "struct", "subscript", "super", "switch", "throw", "throws", "true",
        "try", "typealias", "var", "where", "while",
    ]
}

extension StringProtocol {
    fileprivate var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}
