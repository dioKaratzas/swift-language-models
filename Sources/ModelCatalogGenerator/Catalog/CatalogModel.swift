/// One model as a catalog snapshot stores it: only the facts the generated code uses, in a stable order.
struct CatalogModel: Codable, Equatable, Sendable {
    /// What a provider charges, as the exact decimal text it reports, in US dollars per token, request, image or search.
    ///
    /// Every price but the prompt and completion is optional, so a snapshot written before the catalog kept a price still
    /// decodes.
    struct Pricing: Codable, Equatable, Sendable {
        /// Prices that replace the base prices while every condition it sets holds.
        struct Override: Codable, Equatable, Sendable {
            /// A day of the week, spelled as OpenRouter writes the days of an override and as `Locale.Weekday` names
            /// its cases.
            enum Weekday: String, Codable, Sendable {
                case sunday, monday, tuesday, wednesday, thursday, friday, saturday
            }

            /// The prompt length, in tokens, that a request must exceed.
            let promptTokensAbove: Int?
            /// The days in UTC that a request must be sent on.
            let weekdays: [Weekday]?
            /// The start of a daily window in UTC, as an `HHMM` clock number such as `130` for 01:30.
            let startTime: Int?
            /// The end of the window, exclusive, in the same form.
            let endTime: Int?
            let prompt: String?
            let completion: String?
            let cacheRead: String?
            let cacheWrite: String?
            let cacheWriteOneHour: String?
            /// The price of an audio token in the prompt.
            let audio: String?

            /// Whether the override changes a price the catalog keeps.
            var setsPrice: Bool {
                [prompt, completion, cacheRead, cacheWrite, cacheWriteOneHour, audio].contains { $0 != nil }
            }
        }

        let prompt: String
        let completion: String
        let cacheRead: String?
        /// The price of a prompt-cache write that lasts the provider's default time.
        let cacheWrite: String?
        /// The price of a prompt-cache write that lasts an hour.
        let cacheWriteOneHour: String?
        /// The price of a reasoning token, when it differs from a generated token's.
        let reasoning: String?
        /// The price of an audio token in the prompt.
        let audio: String?
        /// The price of an image in the prompt.
        let image: String?
        /// The fee for each request.
        let request: String?
        /// The price of one web search.
        let webSearch: String?
        /// In the provider's order, where a later override wins; `nil` when there are none, so the file leaves it out.
        let overrides: [Override]?
    }

    let id: String
    let displayName: String
    /// The id of the model an alias points to now.
    let aliasTarget: String?
    /// Seconds since 1970.
    let releasedAt: Int
    let knowledgeCutoff: CatalogDay?
    /// The day the source stops serving the model.
    let expirationDate: CatalogDay?
    let contextSize: Int?
    let maximumOutputTokens: Int?
    /// Sorted.
    let inputModalities: [String]
    /// Sorted.
    let outputModalities: [String]
    /// Sorted.
    let supportedParameters: [String]
    /// Highest first, as the provider lists them; empty when the model's effort can't be chosen.
    let reasoningEfforts: [String]
    let defaultReasoningEffort: String?
    /// Whether and when the model reasons.
    let reasoning: CatalogReasoning
    let pricing: Pricing?
}

extension CatalogModel {
    /// The two flags that snapshots stored before `reasoning`, when OpenRouter was the only source.
    private enum FlagCodingKeys: String, CodingKey {
        case isReasoningMandatory
        case reasonsByDefault
    }

    /// Decodes a model, including one from a snapshot written before the catalog stored `reasoning`, which decides
    /// it from OpenRouter's flags and parameters, as a fetch did then.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        aliasTarget = try container.decodeIfPresent(String.self, forKey: .aliasTarget)
        releasedAt = try container.decode(Int.self, forKey: .releasedAt)
        knowledgeCutoff = try container.decodeIfPresent(CatalogDay.self, forKey: .knowledgeCutoff)
        expirationDate = try container.decodeIfPresent(CatalogDay.self, forKey: .expirationDate)
        contextSize = try container.decodeIfPresent(Int.self, forKey: .contextSize)
        maximumOutputTokens = try container.decodeIfPresent(Int.self, forKey: .maximumOutputTokens)
        inputModalities = try container.decode([String].self, forKey: .inputModalities)
        outputModalities = try container.decode([String].self, forKey: .outputModalities)
        supportedParameters = try container.decode([String].self, forKey: .supportedParameters)
        reasoningEfforts = try container.decode([String].self, forKey: .reasoningEfforts)
        defaultReasoningEffort = try container.decodeIfPresent(String.self, forKey: .defaultReasoningEffort)
        pricing = try container.decodeIfPresent(Pricing.self, forKey: .pricing)
        if let reasoning = try container.decodeIfPresent(CatalogReasoning.self, forKey: .reasoning) {
            self.reasoning = reasoning
        } else {
            let flags = try decoder.container(keyedBy: FlagCodingKeys.self)
            reasoning = OpenRouterModelsResponse.reasoning(
                isMandatory: try flags.decodeIfPresent(Bool.self, forKey: .isReasoningMandatory) ?? false,
                isEnabledByDefault: try flags.decodeIfPresent(Bool.self, forKey: .reasonsByDefault) ?? false,
                parameters: supportedParameters
            )
        }
    }
}
