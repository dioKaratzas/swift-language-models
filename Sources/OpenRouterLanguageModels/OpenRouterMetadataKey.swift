/// The keys of the metadata an OpenRouter answer carries in a Foundation Models session.
///
/// The response or tool-calls entry that ends an answer carries the model, host, generation id and finish reason, and
/// the response entry carries the pages a web search found that the answer cites. The answer's usage carries the cost
/// and the cache write tokens:
///
/// ```swift
/// let response = try await session.respond(to: "Plan dinner.")
/// let cost = response.usage.metadata[OpenRouterMetadataKey.cost]
/// ```
public enum OpenRouterMetadataKey {
    /// The model that answered, such as `anthropic/claude-sonnet-4.6`, which can differ from the one asked for when
    /// OpenRouter routes the request or a fallback answers.
    ///
    /// The request is billed at this model's price. The answer's reasoning entry carries it too, so the reasoning goes
    /// back on later turns only when the model that wrote it isn't a fallback.
    public static let model = "model"

    /// The host that served the answer, such as `Anthropic`.
    public static let provider = "provider"

    /// OpenRouter's id for the answer, such as `gen-…`, for looking up its statistics later.
    public static let generationID = "generationID"

    /// Why the answer ended, as OpenRouter's `finish_reason` names it: `stop` when the model finished, `tool_calls`
    /// when it called tools, or `length` when it reached its token limit and its text is cut short.
    public static let finishReason = "finishReason"

    /// The web pages the answer cites, on its response entry, when the ``OpenRouterServerTool`` web search found them.
    ///
    /// Each is a structure with the page's `url`, and its `title`, `excerpt`, `startIndex` and `endIndex` when known.
    /// `Transcript.Response.openRouterCitations` reads them as ``OpenRouterCitation`` values.
    public static let citations = "citations"

    /// What the answer cost, in US dollars.
    public static let cost = "cost"

    /// The prompt tokens written to the host's prompt cache.
    public static let cacheWriteTokenCount = "cacheWriteTokenCount"
}
