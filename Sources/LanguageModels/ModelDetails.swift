public import FoundationModels

/// What a provider reports about one of its models.
///
/// The identifier is the provider's model id, in a type of the provider's own, so one provider's id can't be passed
/// where another's belongs. Values the provider doesn't report are `nil`.
public protocol ModelDetails: Identifiable, Sendable {
    /// The reasoning levels this model accepts.
    associatedtype Effort: ModelEffort

    /// The model's human-readable name.
    var displayName: String { get }

    /// What the model supports, such as tool calling, image input or reasoning.
    var capabilities: LanguageModelCapabilities { get }

    /// The size of the model's context window, in tokens.
    var contextSize: Int? { get }

    /// The most tokens the model generates in one response.
    var maximumResponseTokens: Int? { get }

    /// The reasoning levels the model accepts, highest first.
    ///
    /// Empty when the model doesn't reason, or when the provider doesn't list its levels.
    var reasoningEfforts: [Effort] { get }

    /// The level the provider uses when a request doesn't set one.
    var defaultReasoningEffort: Effort? { get }
}
