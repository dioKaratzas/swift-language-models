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
            self = model.reasons ? .open : .unsupported
        }
    }

    /// The type's name in generated code.
    var swiftName: String {
        switch self {
        case .set(let words): "Efforts.\(words.map(SwiftIdentifier.effortTypeComponent).joined())"
        case .open: "ContextOptions.ReasoningLevel"
        case .unsupported: "Efforts.Unsupported"
        }
    }

    static func < (lhs: EffortType, rhs: EffortType) -> Bool {
        lhs.swiftName < rhs.swiftName
    }
}
