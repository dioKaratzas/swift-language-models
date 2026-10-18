/// The keys of the metadata an OpenRouter answer carries in a Foundation Models session.
///
/// The response or tool-calls entry that ends an answer carries the model, host and generation id. The answer's usage
/// carries the cost and the cache write tokens:
///
/// ```swift
/// let response = try await session.respond(to: "Plan dinner.")
/// let cost = response.usage.metadata[OpenRouterMetadataKey.cost]
/// ```
public enum OpenRouterMetadataKey {
    /// The model that answered, such as `anthropic/claude-sonnet-4.6`, which can differ from the one asked for when
    /// OpenRouter routes the request.
    public static let model = "model"

    /// The host that served the answer, such as `Anthropic`.
    public static let provider = "provider"

    /// OpenRouter's id for the answer, such as `gen-…`, for looking up its statistics later.
    public static let generationID = "generationID"

    /// What the answer cost, in US dollars.
    public static let cost = "cost"

    /// The prompt tokens written to the host's prompt cache.
    public static let cacheWriteTokenCount = "cacheWriteTokenCount"
}
