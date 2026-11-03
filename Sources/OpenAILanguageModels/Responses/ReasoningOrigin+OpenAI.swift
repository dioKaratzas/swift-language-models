import LanguageModels

extension ReasoningOrigin {
    /// Reasoning that a model wrote through OpenAI's Responses API, which goes back as the answer's `reasoning` items,
    /// with their reasoning encrypted.
    ///
    /// Saved transcripts keep this value, so it never changes.
    static let openAIResponses = Self(rawValue: "openai-responses")
}
