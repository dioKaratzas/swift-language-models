public import Foundation
public import FoundationModels
public import LanguageModels

/// What OpenRouter reports about one of its models.
///
/// Each model in the catalog is a static member whose effort type lists exactly the levels that model accepts. A
/// model picked at runtime uses `ContextOptions.ReasoningLevel` as its effort type instead.
public struct OpenRouterModel<Effort: ModelEffort>: ModelDetails, Equatable {
    /// The model's OpenRouter id, such as `typesafe/jev-router`.
    public let id: String

    /// The model's human-readable name.
    public let displayName: String

    /// When OpenRouter first listed the model.
    public let releaseDate: Date

    /// The day the model's training data ends.
    public let knowledgeCutoff: Date?

    /// The day OpenRouter retires the model.
    public let expirationDate: Date?

    /// The size of the model's context window, in tokens.
    public let contextSize: Int?

    /// The most tokens the model generates in one response.
    public let maximumResponseTokens: Int?

    let inputModalities: Set<String>
    let outputModalities: Set<String>
    let supportedParameters: Set<String>

    /// The reasoning levels the model accepts, highest first.
    public let reasoningEfforts: [Effort]

    /// The level OpenRouter uses when a request doesn't set one.
    public let defaultReasoningEffort: Effort?

    /// Whether the model always reasons, so a request can't turn reasoning off.
    public let isReasoningMandatory: Bool

    /// Whether the model reasons when a request doesn't set a reasoning level.
    public let reasonsByDefault: Bool

    /// What OpenRouter charges for the model, or `nil` when the price depends on the request.
    public let pricing: OpenRouterPricing?

    /// What the model supports, from the request parameters and input kinds it accepts.
    public var capabilities: LanguageModelCapabilities {
        var capabilities: [LanguageModelCapabilities.Capability] = []
        if supportedParameters.contains("tools") { capabilities.append(.toolCalling) }
        if !supportedParameters.isDisjoint(with: ["structured_outputs", "response_format"]) {
            capabilities.append(.guidedGeneration)
        }
        if supportedParameters.contains("reasoning") { capabilities.append(.reasoning) }
        if inputModalities.contains("image") { capabilities.append(.vision) }
        return LanguageModelCapabilities(capabilities)
    }
}

extension OpenRouterModel where Effort == ContextOptions.ReasoningLevel {
    /// The same model with its efforts in their open form, so models with different effort types fit in one list.
    ///
    /// - Parameter typed: A model from the catalog.
    public init(_ typed: OpenRouterModel<some ModelEffort>) {
        self.init(
            id: typed.id,
            displayName: typed.displayName,
            releaseDate: typed.releaseDate,
            knowledgeCutoff: typed.knowledgeCutoff,
            expirationDate: typed.expirationDate,
            contextSize: typed.contextSize,
            maximumResponseTokens: typed.maximumResponseTokens,
            inputModalities: typed.inputModalities,
            outputModalities: typed.outputModalities,
            supportedParameters: typed.supportedParameters,
            reasoningEfforts: typed.reasoningEfforts.map(\.reasoningLevel),
            defaultReasoningEffort: typed.defaultReasoningEffort?.reasoningLevel,
            isReasoningMandatory: typed.isReasoningMandatory,
            reasonsByDefault: typed.reasonsByDefault,
            pricing: typed.pricing
        )
    }
}
