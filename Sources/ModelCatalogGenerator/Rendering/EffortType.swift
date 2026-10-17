/// The effort type of a model's generated member.
enum EffortType: Hashable, Comparable {
    /// A generated enum that lists the model's words, highest first.
    case set(words: [String])
    /// The open `ContextOptions.ReasoningLevel`, for a model that reasons but doesn't list its levels.
    case open
    /// `Efforts.Unsupported`, for a model that doesn't reason.
    case unsupported

    init(for model: CatalogModel, ranking: [String]) {
        if !model.reasoningEfforts.isEmpty {
            let position = Dictionary(uniqueKeysWithValues: ranking.enumerated().map { ($1, $0) })
            self = .set(words: model.reasoningEfforts.sorted { position[$0, default: 0] < position[$1, default: 0] })
        } else {
            self = model.reasoning == .unsupported ? .unsupported : .open
        }
    }

    /// The effort words of a generated set, highest first, or none for the other types.
    var words: [String] {
        if case .set(let words) = self { words } else { [] }
    }

    /// The type's name inside `Efforts`, such as `MaxHighLow`, or `nil` for the open type.
    var typeName: String? {
        switch self {
        case .set(let words): Self.setTypeName(words)
        case .open: nil
        case .unsupported: "Unsupported"
        }
    }

    /// The name inside `Efforts` of the enum for a set of words, such as `MaxHighLow`.
    static func setTypeName(_ words: [String]) -> String {
        words.map(SwiftIdentifier.effortTypeComponent).joined()
    }

    /// The type's name in generated code.
    var swiftName: String {
        typeName.map { "Efforts.\($0)" } ?? "ContextOptions.ReasoningLevel"
    }

    static func < (lhs: EffortType, rhs: EffortType) -> Bool {
        lhs.swiftName < rhs.swiftName
    }
}
