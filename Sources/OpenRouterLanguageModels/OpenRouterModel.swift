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

    /// The size of the model's context window, in tokens.
    public let contextSize: Int?

    /// The most tokens the model generates in one response.
    public let maximumResponseTokens: Int?

    /// The reasoning levels the model accepts, highest first.
    public let reasoningEfforts: [Effort]

    /// The level OpenRouter uses when a request doesn't set one.
    public let defaultReasoningEffort: Effort?

    /// What OpenRouter charges for the model, or `nil` when the price depends on the request.
    public let pricing: OpenRouterPricing?

    let inputModalities: Set<String>
    let supportedParameters: Set<String>

    init(
        id: String,
        displayName: String,
        contextSize: Int?,
        maximumResponseTokens: Int?,
        inputModalities: Set<String>,
        supportedParameters: Set<String>,
        reasoningEfforts: [Effort],
        defaultReasoningEffort: Effort?,
        pricing: OpenRouterPricing?
    ) {
        self.id = id
        self.displayName = displayName
        self.contextSize = contextSize
        self.maximumResponseTokens = maximumResponseTokens
        self.inputModalities = inputModalities
        self.supportedParameters = supportedParameters
        self.reasoningEfforts = reasoningEfforts
        self.defaultReasoningEffort = defaultReasoningEffort
        self.pricing = pricing
    }

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
            contextSize: typed.contextSize,
            maximumResponseTokens: typed.maximumResponseTokens,
            inputModalities: typed.inputModalities,
            supportedParameters: typed.supportedParameters,
            reasoningEfforts: typed.reasoningEfforts.map(\.reasoningLevel),
            defaultReasoningEffort: typed.defaultReasoningEffort?.reasoningLevel,
            pricing: typed.pricing
        )
    }
}
