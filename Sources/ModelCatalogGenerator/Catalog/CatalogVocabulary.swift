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
}
