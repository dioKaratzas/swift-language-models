/// A Swift expression that lays itself out the way `swift format` keeps it: on one line when that fits, otherwise
/// with one element per line, each laid out the same way.
enum SwiftExpression {
    /// A call's argument.
    struct Argument {
        let label: String
        let value: SwiftExpression
    }

    /// Text that never breaks, such as a literal.
    case atom(String)
    /// An array literal.
    case array([SwiftExpression])
    /// A call, such as `Self(id: "a")`.
    case call(String, arguments: [Argument])

    /// A call with only the arguments that have a value, so an argument left at its default can be `nil`.
    static func call(_ name: String, _ arguments: KeyValuePairs<String, SwiftExpression?>) -> SwiftExpression {
        .call(name, arguments: arguments.compactMap { label, value in value.map { Argument(label: label, value: $0) } })
    }

    /// The expression on one line.
    var line: String {
        switch self {
        case .atom(let text): text
        case .array(let elements): "[\(elements.map(\.line).joined(separator: ", "))]"
        case .call(let name, let arguments):
            "\(name)(\(arguments.map { "\($0.label): \($0.value.line)" }.joined(separator: ", ")))"
        }
    }

    /// The expression's lines, after `prefix`, such as a label, and before `suffix`, such as a comma.
    ///
    /// - Parameters:
    ///   - indent: The indentation of the first and last lines; elements get four more spaces.
    ///   - prefix: Text before the expression on its first line.
    ///   - suffix: Text after the expression on its last line.
    ///   - breaks: Whether to break the expression even when it fits on one line.
    /// - Returns: The lines, without line breaks.
    func lines(indent: String, prefix: String = "", suffix: String = "", breaks: Bool = false) -> [String] {
        let oneLine = indent + prefix + line + suffix
        guard breaks || oneLine.count >= SourceText.lineLength else { return [oneLine] }
        let inner = indent + "    "
        switch self {
        case .array(let elements) where !elements.isEmpty:
            // `swift format` puts a comma after every element of a broken array, unless it has only one.
            let comma = elements.count > 1 ? "," : ""
            return [indent + prefix + "["] + elements.flatMap { $0.lines(indent: inner, suffix: comma) } + [indent + "]" + suffix]
        case .call(let name, let arguments) where !arguments.isEmpty:
            let argumentLines = arguments.enumerated().flatMap { index, argument in
                argument.value.lines(indent: inner, prefix: "\(argument.label): ", suffix: index < arguments.count - 1 ? "," : "")
            }
            return [indent + prefix + name + "("] + argumentLines + [indent + ")" + suffix]
        default:
            return [oneLine]
        }
    }
}
