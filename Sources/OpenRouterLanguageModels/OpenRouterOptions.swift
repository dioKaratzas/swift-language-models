/// Request settings that only OpenRouter has, beyond Foundation Models' generation options.
///
/// Each sampling setting reaches the model only if the model lists its parameter, such as `frequency_penalty`, so a
/// setting a model doesn't take is left out instead of failing the request. Every setting left `nil` keeps the
/// model's default.
public struct OpenRouterOptions: Sendable, Hashable {
    /// Lowers the chance of a token by how often it already appeared, from -2 to 2.
    public var frequencyPenalty: Double?

    /// Lowers the chance of a token that already appeared at all, from -2 to 2.
    public var presencePenalty: Double?

    /// Scales down the chance of tokens that already appeared; 1 means no penalty.
    public var repetitionPenalty: Double?

    /// Drops tokens whose chance is below this fraction of the most likely token's, from 0 to 1.
    public var minP: Double?

    /// Keeps only tokens with a chance close enough to the most likely token's, from 0 to 1.
    public var topA: Double?

    /// Text that ends the response when the model generates it, up to four sequences.
    public var stopSequences: [String]?

    /// Changes to the chance of specific tokens, by token id, from -100 to 100.
    public var logitBias: [Int: Double]?

    /// The processing tier, such as `flex` or `priority`, which trades speed against price.
    public var serviceTier: OpenRouterServiceTier?

    /// A stable id for the app's end user, such as a hash, so a host can tell users apart for abuse checks.
    public var endUserID: String?

    /// Creates request settings.
    ///
    /// - Parameters:
    ///   - frequencyPenalty: Lowers the chance of a token by how often it already appeared.
    ///   - presencePenalty: Lowers the chance of a token that already appeared at all.
    ///   - repetitionPenalty: Scales down the chance of tokens that already appeared.
    ///   - minP: Drops tokens whose chance is below this fraction of the most likely token's.
    ///   - topA: Keeps only tokens with a chance close enough to the most likely token's.
    ///   - stopSequences: Text that ends the response when the model generates it.
    ///   - logitBias: Changes to the chance of specific tokens, by token id.
    ///   - serviceTier: The processing tier.
    ///   - endUserID: A stable id for the app's end user.
    public init(
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        repetitionPenalty: Double? = nil,
        minP: Double? = nil,
        topA: Double? = nil,
        stopSequences: [String]? = nil,
        logitBias: [Int: Double]? = nil,
        serviceTier: OpenRouterServiceTier? = nil,
        endUserID: String? = nil
    ) {
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.repetitionPenalty = repetitionPenalty
        self.minP = minP
        self.topA = topA
        self.stopSequences = stopSequences
        self.logitBias = logitBias
        self.serviceTier = serviceTier
        self.endUserID = endUserID
    }
}
