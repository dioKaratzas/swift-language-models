public import LanguageModels

/// Why OpenRouter ended an answer, as its `finish_reason` names it, such as `stop` or `length`.
///
/// The entry that ends an answer carries it, and ``OpenRouterResponseMetadata/finishReason`` reads it from a response
/// entry. An answer cut off at its token limit doesn't throw, so its reason is the way to tell:
///
/// ```swift
/// let response = try await session.respond(to: "Plan the week.", options: GenerationOptions(maximumResponseTokens: 200))
/// if case .response(let answer)? = response.transcriptEntries.last, answer.openRouter.finishReason == .length {
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
}
