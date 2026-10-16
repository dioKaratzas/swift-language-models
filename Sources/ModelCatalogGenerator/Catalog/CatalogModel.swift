/// One model as a catalog snapshot stores it: only the facts the generated code uses, in a stable order.
struct CatalogModel: Codable, Equatable, Sendable {
    /// What a provider charges, as the exact decimal text it reports, in US dollars per token.
    struct Pricing: Codable, Equatable, Sendable {
        let prompt: String
        let completion: String
        let cacheRead: String?
        let cacheWrite: String?
    }

    let id: String
    let displayName: String
    /// Seconds since 1970.
    let releasedAt: Int
    /// As `yyyy-MM-dd`.
    let knowledgeCutoff: String?
    /// As `yyyy-MM-dd`.
    let expirationDate: String?
    let contextSize: Int?
    let maximumResponseTokens: Int?
    /// Sorted.
    let inputModalities: [String]
    /// Sorted.
    let outputModalities: [String]
    /// Sorted.
    let supportedParameters: [String]
    /// Highest first, as the provider lists them.
    let reasoningEfforts: [String]
    let defaultReasoningEffort: String?
    let isReasoningMandatory: Bool
    let reasonsByDefault: Bool
    let pricing: Pricing?

    /// Whether the model accepts a reasoning setting.
    var reasons: Bool { supportedParameters.contains("reasoning") }
}
