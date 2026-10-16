public import FoundationModels

/// A language model that carries what its provider reports about it.
///
/// The model's capabilities come from its details.
public protocol DetailedLanguageModel: LanguageModel {
    /// The type that describes the model.
    associatedtype Details: ModelDetails

    /// What the provider reports about this model.
    var details: Details { get }
}

extension DetailedLanguageModel {
    /// The capabilities from the model's details.
    public var capabilities: LanguageModelCapabilities { details.capabilities }
}
