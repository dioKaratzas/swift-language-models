/// Whether and when a catalog model reasons, as one value, so no impossible combination of flags can reach the code.
///
/// A snapshot stores it as one word: `unsupported`, `offByDefault`, `onByDefault` or `mandatory`.
enum CatalogReasoning: Equatable, Sendable, CaseIterable {
    case unsupported
    case optional(enabledByDefault: Bool)
    case mandatory

    static let allCases: [CatalogReasoning] = [
        .unsupported, .optional(enabledByDefault: false), .optional(enabledByDefault: true), .mandatory,
    ]

    /// The word a snapshot stores.
    private var word: String {
        switch self {
        case .unsupported: "unsupported"
        case .optional(enabledByDefault: false): "offByDefault"
        case .optional(enabledByDefault: true): "onByDefault"
        case .mandatory: "mandatory"
        }
    }
}

extension CatalogReasoning: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let word = try container.decode(String.self)
        guard let reasoning = Self.allCases.first(where: { $0.word == word }) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "'\(word)' isn't a kind of reasoning.")
        }
        self = reasoning
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(word)
    }
}
