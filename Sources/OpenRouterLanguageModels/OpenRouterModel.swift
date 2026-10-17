public import Foundation
public import FoundationModels
public import LanguageModels
public import UniformTypeIdentifiers

/// What OpenRouter reports about one of its models.
///
/// Each model in the catalog is a static member whose effort type lists exactly the levels that model accepts. A
/// model picked at runtime uses `ContextOptions.ReasoningLevel` as its effort type instead.
public struct OpenRouterModel<Effort: ModelEffort>: ModelDetails, Equatable {
    /// The model's OpenRouter id, such as `typesafe/jev-router`.
    public let id: OpenRouterModelID

    /// The model's human-readable name.
    public let displayName: String

    /// When OpenRouter first listed the model.
    public let releaseDate: Date

    /// The model that an alias, such as `~deepseek/deepseek-pro-latest`, points to now, or `nil` for a model that
    /// isn't an alias.
    public let aliasTarget: OpenRouterModelID?

    /// The day the model's training data ends, at midnight UTC.
    public let knowledgeCutoff: Date?

    /// The day OpenRouter retires the model, at midnight UTC.
    public let expirationDate: Date?

    /// The size of the model's context window, in tokens.
    public let contextSize: Int?

    /// The most tokens the model generates in one response.
    public let maximumResponseTokens: Int?

    /// The kinds of input the model accepts, such as text, images or files.
    public let inputModalities: Set<OpenRouterInputModality>

    /// The kinds of output the model generates, such as text or images.
    public let outputModalities: Set<OpenRouterOutputModality>

    /// The request parameters the model accepts, such as `tools` or `seed`.
    public let supportedParameters: Set<OpenRouterParameter>

    /// Whether and when the model reasons.
    public let reasoning: OpenRouterReasoning

    /// The reasoning levels the model accepts, highest first, or none when its level can't be chosen.
    public let reasoningEfforts: [Effort]

    /// The level OpenRouter uses when a request doesn't set one.
    public let defaultReasoningEffort: Effort?

    /// What OpenRouter charges for the model, or `nil` when the price depends on the request.
    public let pricing: OpenRouterPricing?

    /// Creates a model's details.
    ///
    /// - Parameters:
    ///   - id: The model's OpenRouter id.
    ///   - displayName: The model's human-readable name.
    ///   - releaseDate: When OpenRouter first listed the model.
    ///   - aliasTarget: The model an alias points to now.
    ///   - knowledgeCutoff: The day the model's training data ends.
    ///   - expirationDate: The day OpenRouter retires the model.
    ///   - contextSize: The size of the model's context window, in tokens.
    ///   - maximumResponseTokens: The most tokens the model generates in one response.
    ///   - inputModalities: The kinds of input the model accepts.
    ///   - outputModalities: The kinds of output the model generates.
    ///   - supportedParameters: The request parameters the model accepts.
    ///   - reasoning: Whether and when the model reasons.
    ///   - reasoningEfforts: The reasoning levels the model accepts, highest first.
    ///   - defaultReasoningEffort: The level OpenRouter uses when a request doesn't set one.
    ///   - pricing: What OpenRouter charges for the model.
    public init(
        id: OpenRouterModelID,
        displayName: String,
        releaseDate: Date,
        aliasTarget: OpenRouterModelID? = nil,
        knowledgeCutoff: Date? = nil,
        expirationDate: Date? = nil,
        contextSize: Int? = nil,
        maximumResponseTokens: Int? = nil,
        inputModalities: Set<OpenRouterInputModality> = [.text],
        outputModalities: Set<OpenRouterOutputModality> = [.text],
        supportedParameters: Set<OpenRouterParameter> = [],
        reasoning: OpenRouterReasoning = .unsupported,
        reasoningEfforts: [Effort] = [],
        defaultReasoningEffort: Effort? = nil,
        pricing: OpenRouterPricing? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.releaseDate = releaseDate
        self.aliasTarget = aliasTarget
        self.knowledgeCutoff = knowledgeCutoff
        self.expirationDate = expirationDate
        self.contextSize = contextSize
        self.maximumResponseTokens = maximumResponseTokens
        self.inputModalities = inputModalities
        self.outputModalities = outputModalities
        self.supportedParameters = supportedParameters
        self.reasoning = reasoning
        self.reasoningEfforts = reasoningEfforts
        self.defaultReasoningEffort = defaultReasoningEffort
        self.pricing = pricing
    }

    /// What the model supports, from the request parameters and input kinds it accepts.
    public var capabilities: LanguageModelCapabilities {
        var capabilities: [LanguageModelCapabilities.Capability] = []
        if supportedParameters.contains(.tools) { capabilities.append(.toolCalling) }
        if !supportedParameters.isDisjoint(with: [.structuredOutputs, .responseFormat]) {
            capabilities.append(.guidedGeneration)
        }
        if reasoning != .unsupported { capabilities.append(.reasoning) }
        if inputModalities.contains(.image) { capabilities.append(.vision) }
        return LanguageModelCapabilities(capabilities)
    }

    /// The attachment kinds of the inputs the model accepts.
    public var dataAttachmentTypes: Set<UTType> {
        Set(inputModalities.compactMap(\.contentType))
    }

    /// The data kinds of the outputs the model generates besides text.
    public var dataEntryTypes: Set<UTType> {
        Set(outputModalities.compactMap(\.contentType))
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
            aliasTarget: typed.aliasTarget,
            knowledgeCutoff: typed.knowledgeCutoff,
            expirationDate: typed.expirationDate,
            contextSize: typed.contextSize,
            maximumResponseTokens: typed.maximumResponseTokens,
            inputModalities: typed.inputModalities,
            outputModalities: typed.outputModalities,
            supportedParameters: typed.supportedParameters,
            reasoning: typed.reasoning,
            reasoningEfforts: typed.reasoningEfforts.map(\.reasoningLevel),
            defaultReasoningEffort: typed.defaultReasoningEffort?.reasoningLevel,
            pricing: typed.pricing
        )
    }
}
