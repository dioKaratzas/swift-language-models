public import FoundationModels
import LanguageModels

/// What OpenAI reported about an answer's counts beyond Foundation Models' own, read from its usage's metadata.
///
/// `LanguageModelSession.Usage.openAI` reads it. The usage's own input, cached, output and reasoning token counts hold
/// the rest, and the package keeps no prices, so it reports no cost. A fact OpenAI didn't report is `nil`:
///
/// ```swift
/// let response = try await session.respond(to: "Plan dinner.")
/// if let written = response.usage.openAI.cacheWriteTokenCount {
///     print("\(written) prompt tokens went into OpenAI's cache.")
/// }
/// ```
///
/// The facts are those of one request. A response whose tool calls ran has the last request's, and a session's own
/// `usage` keeps no metadata, so its facts are all `nil`. Each request's facts are also on the transcript entry that
/// ends it, which ``OpenAIResponseMetadata/usage`` reads.
public struct OpenAIUsageMetadata: Sendable, Hashable {
    /// The prompt tokens written to OpenAI's prompt cache.
    public let cacheWriteTokenCount: Int?

    /// The facts in a usage's metadata.
    init(_ metadata: [String: GeneratedContent]) {
        cacheWriteTokenCount = MetadataValues(metadata).integer(LanguageModelMetadataKey.cacheWriteTokenCount)
    }
}

extension LanguageModelSession.Usage {
    /// What OpenAI reported about the answer's counts, such as the prompt tokens written to its cache.
    public var openAI: OpenAIUsageMetadata {
        OpenAIUsageMetadata(metadata)
    }
}
