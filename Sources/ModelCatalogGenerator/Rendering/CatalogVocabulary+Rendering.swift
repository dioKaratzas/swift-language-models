extension CatalogVocabulary {
    /// The doc summary of a word that the source doesn't describe.
    func fallbackSummary(for word: String) -> String {
        switch self {
        case .inputModalities: "The `\(word)` input kind."
        case .outputModalities: "The `\(word)` output kind."
        case .parameters: "The `\(word)` parameter."
        }
    }
}
