public import LanguageModels

/// A request setting that an OpenAI model accepts, such as `tools` or `temperature`.
///
/// Parameters are an open vocabulary: any name the catalog lists is a valid parameter, with or without a static member.
/// `structured_outputs` stands for answers held to a schema, and `reasoning` for a choice of reasoning effort.
public struct OpenAIParameter: ProviderVocabulary {
    /// The parameter's name, as the catalog spells it.
    public let rawValue: String

    /// Creates a parameter from its name.
    ///
    /// - Parameter rawValue: The name, such as `"top_p"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
