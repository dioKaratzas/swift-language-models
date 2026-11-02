import LanguageModels

extension ReasoningOrigin {
    /// Reasoning that a model wrote through OpenRouter's Chat Completions API, which goes back as the text and
    /// `reasoning_details` of an assistant message.
    ///
    /// Saved transcripts keep this value, so it stays `openrouter`, although it names the format too. Reasoning that
    /// OpenRouter returns in another format gets an origin of its own, so it isn't sent back in this shape.
    static let openRouter = Self(rawValue: "openrouter")
}
