/// The effort type of a model's generated member: a generated enum that lists the model's words, or
/// `Efforts.Unsupported` for a model whose reasoning level can't be chosen.
struct EffortType: Hashable, Comparable {
    /// The names inside `Efforts` that no generated enum can take: the hand-written `Unsupported`, and the names
    /// Swift gives every type.
    static let reservedNames: Set<String> = ["Unsupported", "Protocol", "Self", "Type"]

    /// The effort words, highest first, or none for `Unsupported`.
    let words: [String]

    /// The type for a set of words, which it lists in the ranking's order.
    init(words: [String], ranking: EffortRanking) {
        self.words = ranking.sorted(words)
    }

    /// The type of a model's member.
    init(for model: CatalogModel, ranking: EffortRanking) {
        self.init(words: model.reasoningEfforts, ranking: ranking)
    }

    /// The type's name inside `Efforts`, such as `MaxHighLow`.
    var name: SwiftIdentifier {
        words.isEmpty ? SwiftIdentifier(name: "Unsupported") : SwiftIdentifier.effortType(for: words)
    }

    /// The type's name in generated code.
    var swiftName: String { "Efforts.\(name)" }

    static func < (lhs: EffortType, rhs: EffortType) -> Bool {
        lhs.swiftName < rhs.swiftName
    }
}
