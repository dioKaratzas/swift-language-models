public import FoundationModels

/// What ``DetailedLanguageModelExecutor`` reads from a model before each request: its details and its fallbacks.
///
/// A provider module's model conforms to ``DetailedLanguageModel``, which refines this protocol. This protocol exists
/// so that a request executor's model has a type the executor can read, since ``DetailedLanguageModel`` names the
/// executor itself.
public protocol DetailedLanguageModelBase: LanguageModel {
    /// The type that describes the model.
    associatedtype Details: ModelDetails

    /// The type that describes the models the provider tries when this one fails.
    associatedtype Fallback: ModelDetails

    /// What the provider reports about this model.
    var details: Details { get }

    /// The models the provider tries, in order, when this one fails. Empty when the provider has no fallbacks.
    var fallbacks: [Fallback] { get }
}

/// A language model that carries what its provider reports about it.
///
/// The model's capabilities, and the kinds of data it accepts and generates, come from its details. Its executor is a
/// ``DetailedLanguageModelExecutor`` of the provider module's ``RequestExecutor``, which checks each request before the
/// request executor sends it.
public protocol DetailedLanguageModel: DetailedLanguageModelBase
where Executor == DetailedLanguageModelExecutor<RequestExecutor> {
    /// The type that sends the model's requests.
    associatedtype RequestExecutor: DetailedLanguageModelRequestExecutor where RequestExecutor.Model == Self
}

extension DetailedLanguageModel {
    /// The capabilities from the model's details.
    public var capabilities: LanguageModelCapabilities { details.capabilities }
}
