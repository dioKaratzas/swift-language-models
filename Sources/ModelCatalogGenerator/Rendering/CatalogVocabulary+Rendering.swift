extension CatalogVocabulary {
    /// The doc summary of a word that the source doesn't describe.
    func fallbackSummary(for word: String) -> String {
        switch self {
        case .inputModalities: "The `\(word)` input kind."
        case .outputModalities: "The `\(word)` output kind."
        case .parameters: "The `\(word)` parameter."
        case .searchContextSizes: "The `\(word)` search context size."
        case .webFetchEngines: "The `\(word)` web fetch engine."
        case .webSearchEngines: "The `\(word)` web search engine."
        case .webSearchModes: "The `\(word)` search mode."
        }
    }
}
