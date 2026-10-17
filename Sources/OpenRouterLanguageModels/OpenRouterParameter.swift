public import LanguageModels

/// A request parameter that an OpenRouter model accepts, such as `tools` or `temperature`.
///
/// Parameters are an open vocabulary: any name OpenRouter lists is a valid parameter, with or without a static member.
public struct OpenRouterParameter: ProviderVocabulary {
    /// The most tokens to generate, in OpenAI's newer spelling.
    public static let maxCompletionTokens: Self = "max_completion_tokens"
    /// The most tokens to generate.
    public static let maxTokens: Self = "max_tokens"
    /// Whether the model may call several tools at once.
    public static let parallelToolCalls: Self = "parallel_tool_calls"
    /// Reasoning settings, such as the effort.
    public static let reasoning: Self = "reasoning"
    /// JSON output, with or without a schema.
    public static let responseFormat: Self = "response_format"
    /// A seed for repeatable sampling.
    public static let seed: Self = "seed"
    /// Output that follows a JSON schema exactly.
    public static let structuredOutputs: Self = "structured_outputs"
    /// The sampling temperature.
    public static let temperature: Self = "temperature"
    /// Whether and which tools the model must call.
    public static let toolChoice: Self = "tool_choice"
    /// Tools the model can call.
    public static let tools: Self = "tools"
    /// Sampling from the most likely tokens only.
    public static let topK: Self = "top_k"
    /// Sampling from the smallest set of tokens above a probability.
    public static let topP: Self = "top_p"

    /// The parameter's name in OpenRouter's API.
    public let rawValue: String

    /// Creates a parameter from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"top_p"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
