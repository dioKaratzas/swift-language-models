/// An open vocabulary of a source's API whose words each get a static member, such as the request parameter names.
enum CatalogVocabulary: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case inputModalities
    case outputModalities
    case parameters

    /// The vocabulary's words that a model uses.
    func words(of model: CatalogModel) -> [String] {
        switch self {
        case .inputModalities: model.inputModalities
        case .outputModalities: model.outputModalities
        case .parameters: model.supportedParameters
        }
    }

    /// The doc summary of a word that the source doesn't describe.
    func fallbackSummary(for word: String) -> String {
        switch self {
        case .inputModalities: "The `\(word)` input kind."
        case .outputModalities: "The `\(word)` output kind."
        case .parameters: "The `\(word)` parameter."
        }
    }
}
