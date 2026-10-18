/// Why OpenRouter's stream ended a response.
struct FinishReason: RawRepresentable, Hashable, Sendable, Decodable {
    /// The model finished.
    static let stop = Self(rawValue: "stop")

    /// The response reached its token limit.
    static let length = Self(rawValue: "length")

    /// The model asked for tool calls.
    static let toolCalls = Self(rawValue: "tool_calls")

    /// A content filter stopped the response.
    static let contentFilter = Self(rawValue: "content_filter")

    /// The host failed while generating.
    static let error = Self(rawValue: "error")

    let rawValue: String
}
