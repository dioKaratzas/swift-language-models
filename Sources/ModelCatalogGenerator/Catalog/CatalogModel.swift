/// One model as a catalog snapshot stores it: only the facts the generated code uses, in a stable order.
struct CatalogModel: Codable, Equatable, Sendable {
    /// What a provider charges, as the exact decimal text it reports, in US dollars per token.
    struct Pricing: Codable, Equatable, Sendable {
        /// Prices that replace the base prices while every condition it sets holds.
        struct Override: Codable, Equatable, Sendable {
            /// The prompt length, in tokens, that a request must exceed.
            let promptTokensAbove: Int?
            /// Lowercase English day names in UTC, such as `monday`.
            let weekdays: [String]?
            /// The start of a daily window in UTC, as an `HHMM` clock number such as `130` for 01:30.
            let startTime: Int?
            /// The end of the window, exclusive, in the same form.
            let endTime: Int?
            let prompt: String?
            let completion: String?
            let cacheRead: String?
            let cacheWrite: String?
            let cacheWriteOneHour: String?

            /// Whether the override changes a price the catalog keeps.
            var setsPrice: Bool {
                [prompt, completion, cacheRead, cacheWrite, cacheWriteOneHour].contains { $0 != nil }
            }
        }

        let prompt: String
        let completion: String
        let cacheRead: String?
        /// The price of a prompt-cache write that lasts the provider's default time.
        let cacheWrite: String?
        /// The price of a prompt-cache write that lasts an hour.
        let cacheWriteOneHour: String?
        /// In the provider's order, where a later override wins; `nil` when there are none, so the file leaves it out.
        let overrides: [Override]?
    }

    let id: String
    let displayName: String
    /// The id of the model an alias points to now.
    let aliasTarget: String?
    /// Seconds since 1970.
    let releasedAt: Int
    /// As `yyyy-MM-dd`.
    let knowledgeCutoff: String?
    /// As `yyyy-MM-dd`.
    let expirationDate: String?
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
    let isReasoningMandatory: Bool
    let reasonsByDefault: Bool
    let pricing: Pricing?

    /// Whether and when the model reasons: mandatory reasoning wins, and otherwise the `reasoning` parameter decides.
    var reasoning: CatalogReasoning {
        if isReasoningMandatory { return .mandatory }
        return supportedParameters.contains("reasoning") ? .optional(enabledByDefault: reasonsByDefault) : .unsupported
    }
}
