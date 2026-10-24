public import FoundationModels
public import LanguageModels

/// Why OpenRouter ended an answer, as its `finish_reason` names it, such as `stop` or `length`.
///
/// The entry that ends an answer carries it, and `Transcript.Response.openRouterFinishReason` reads it from a response
/// entry. An answer cut off at its token limit doesn't throw, so its reason is the way to tell:
///
/// ```swift
/// let response = try await session.respond(to: "Plan the week.", options: GenerationOptions(maximumResponseTokens: 200))
/// if case .response(let answer)? = response.transcriptEntries.last, answer.openRouterFinishReason == .length {
///     // The plan was cut short.
/// }
/// ```
///
/// An answer that a content filter stopped or that ended in an error throws instead, so no entry carries
/// ``contentFilter`` or ``error``. Any reason a host sends is valid, with or without a static member.
public struct OpenRouterFinishReason: ProviderVocabulary {
    /// The model finished.
    public static let stop: Self = "stop"

    /// The answer reached its token limit, so its text is cut short.
    public static let length: Self = "length"

    /// The model asked for tool calls.
    public static let toolCalls: Self = "tool_calls"

    /// A content filter stopped the answer.
    public static let contentFilter: Self = "content_filter"

    /// The host failed while generating.
    public static let error: Self = "error"

    /// The reason as OpenRouter's `finish_reason` spells it.
    public let rawValue: String

    /// Creates a reason from OpenRouter's spelling of it.
    ///
    /// - Parameter rawValue: The reason, such as `"length"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a reason from a string literal of OpenRouter's spelling of it.
    ///
    /// - Parameter value: The reason, such as `"length"`.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// The raw value, so printing a value shows OpenRouter's spelling of it.
    public var description: String { rawValue }
}

extension Transcript.Response {
    /// Why the answer ended, such as ``OpenRouterFinishReason/length`` when it reached its token limit, or `nil` for an
    /// entry that doesn't end an answer.
    ///
    /// It reads ``OpenRouterMetadataKey/finishReason``, a shared key, so another language model's answer reads too, in
    /// that model's own words.
    public var openRouterFinishReason: OpenRouterFinishReason? {
        guard case .string(let reason)? = metadata[OpenRouterMetadataKey.finishReason]?.kind else { return nil }
        return OpenRouterFinishReason(rawValue: reason)
    }
}
