/// An open vocabulary of a source's API whose words each get a static member, such as the request parameter names or
/// the web search engines.
enum CatalogVocabulary: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case inputModalities
    case outputModalities
    case parameters
    case searchContextSizes
    case webFetchEngines
    case webSearchEngines
    case webSearchModes

    /// The vocabulary's words that a model uses, which are none for a vocabulary of request settings.
    func words(of model: CatalogModel) -> [String] {
        switch self {
        case .inputModalities: model.inputModalities
        case .outputModalities: model.outputModalities
        case .parameters: model.supportedParameters
        case .searchContextSizes, .webFetchEngines, .webSearchEngines, .webSearchModes: []
        }
    }
}
