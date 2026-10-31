public import Foundation

/// What OpenRouter lists for a model now: its prices, limits and parameters, which can change after the catalog was
/// generated.
///
/// ``OpenRouterModel/currentDetails(auth:session:)`` reads them, and
/// ``OpenRouterModel/currentPricing(auth:session:)`` reads only the prices.
public struct OpenRouterCurrentDetails: Sendable, Hashable {
    /// The model's OpenRouter id, such as `anthropic/claude-haiku-5.5`.
    public let id: OpenRouterModelID

    /// The model's human-readable name.
    public let displayName: String

    /// The model that an alias, such as `~anthropic/claude-haiku-latest`, points to now, or `nil` for a model that
    /// isn't an alias.
    public let aliasTarget: OpenRouterModelID?

    /// The size of the model's context window, in tokens.
    public let contextSize: Int?

    /// The most tokens the model can generate in one response, at the provider OpenRouter ranks first.
    public let maximumOutputTokens: Int?

    /// What OpenRouter charges for the model, or `nil` when the price depends on the request, as for a router.
    ///
    /// The model's endpoints can charge other prices; ``OpenRouterModel/providers(auth:session:)`` lists
    /// each one's.
    public let pricing: OpenRouterPricing?

    /// The request parameters the model accepts, such as `tools` or `seed`.
    public let supportedParameters: Set<OpenRouterParameter>

    /// Whether the provider OpenRouter ranks first moderates content.
    public let isModerated: Bool

    /// The day OpenRouter retires the model, at midnight UTC.
    public let expirationDate: Date?

    /// Creates a model's current details, such as for a preview.
    ///
    /// - Parameters:
    ///   - id: The model's OpenRouter id.
    ///   - displayName: The model's human-readable name.
    ///   - aliasTarget: The model an alias points to now.
    ///   - contextSize: The size of the model's context window, in tokens.
    ///   - maximumOutputTokens: The most tokens the model can generate in one response.
    ///   - pricing: What OpenRouter charges for the model.
    ///   - supportedParameters: The request parameters the model accepts.
    ///   - isModerated: Whether the provider OpenRouter ranks first moderates content.
    ///   - expirationDate: The day OpenRouter retires the model.
    public init(
        id: OpenRouterModelID,
        displayName: String,
        aliasTarget: OpenRouterModelID? = nil,
        contextSize: Int? = nil,
        maximumOutputTokens: Int? = nil,
        pricing: OpenRouterPricing? = nil,
        supportedParameters: Set<OpenRouterParameter> = [],
        isModerated: Bool = false,
        expirationDate: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.aliasTarget = aliasTarget
        self.contextSize = contextSize
        self.maximumOutputTokens = maximumOutputTokens
        self.pricing = pricing
        self.supportedParameters = supportedParameters
        self.isModerated = isModerated
        self.expirationDate = expirationDate
    }
}

/// The `data` of `GET /model/{author}/{slug}`.
struct ModelPayload: Decodable, Sendable {
    struct AliasTarget: Decodable, Sendable {
        let slug: String
    }

    struct TopProvider: Decodable, Sendable {
        let maxCompletionTokens: Int?
        let isModerated: Bool?

        private enum CodingKeys: String, CodingKey {
            case maxCompletionTokens = "max_completion_tokens"
            case isModerated = "is_moderated"
        }
    }

    let id: String
    let name: String
    let aliasTarget: AliasTarget?
    let contextLength: Int?
    let topProvider: TopProvider?
    let pricing: PricingPayload?
    let supportedParameters: [String]?
    /// The day as `YYYY-MM-DD`.
    let expirationDate: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, pricing
        case aliasTarget = "alias_target"
        case contextLength = "context_length"
        case topProvider = "top_provider"
        case supportedParameters = "supported_parameters"
        case expirationDate = "expiration_date"
    }
}

extension OpenRouterCurrentDetails {
    init(_ payload: ModelPayload) {
        self.init(
            id: OpenRouterModelID(rawValue: payload.id),
            displayName: payload.name,
            aliasTarget: payload.aliasTarget.map { OpenRouterModelID(rawValue: $0.slug) },
            contextSize: payload.contextLength,
            maximumOutputTokens: payload.topProvider?.maxCompletionTokens,
            pricing: payload.pricing.flatMap(OpenRouterPricing.init),
            supportedParameters: Set((payload.supportedParameters ?? []).map(OpenRouterParameter.init(rawValue:))),
            isModerated: payload.topProvider?.isModerated ?? false,
            expirationDate: payload.expirationDate.flatMap(Self.midnightUTC)
        )
    }

    /// Midnight UTC at the start of a day written as `YYYY-MM-DD`, or `nil` for text that isn't such a day.
    private static func midnightUTC(_ day: String) -> Date? {
        try? Date(day, strategy: Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day())
    }
}

extension APITransport {
    /// One model's current details.
    func currentDetails(of model: OpenRouterModelID, headers: [String: String]) async throws -> OpenRouterCurrentDetails {
        OpenRouterCurrentDetails(try await value(at: "model/\(model.rawValue)", headers: headers, as: DataEnvelope<ModelPayload>.self).data)
    }
}
