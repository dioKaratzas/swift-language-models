/// One model as a catalog snapshot stores it: only the facts the generated code uses, in a stable order.
struct CatalogModel: Codable, Equatable, Sendable {
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
    /// Whether the model's hosts cache a prompt only when the request marks it.
    let cachesOnlyMarkedPrompts: Bool
}

extension CatalogModel {
    /// The two flags that snapshots stored before `reasoning`, when OpenRouter was the only source.
    private enum FlagCodingKeys: String, CodingKey {
        case isReasoningMandatory
        case reasonsByDefault
    }

    /// Decodes a model, including one from an older snapshot: without `reasoning`, it's decided from OpenRouter's
    /// flags and parameters, as a fetch did then, and without `cachesOnlyMarkedPrompts`, it's `false`.
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
        cachesOnlyMarkedPrompts = try container.decodeIfPresent(Bool.self, forKey: .cachesOnlyMarkedPrompts) ?? false
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
