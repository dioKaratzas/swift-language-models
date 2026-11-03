public import LanguageModels

/// An OpenAI model id, such as `gpt-6-luna`.
///
/// A distinct type, so text that isn't an OpenAI id, such as a display name or another provider's id, can't be passed
/// by mistake.
///
/// To make ids from strings, name the initializer in full, since a bare `OpenAIModelID.init` could also mean the
/// string-literal one:
///
/// ```swift
/// let ids = savedIDs.map(OpenAIModelID.init(rawValue:))
/// ```
public struct OpenAIModelID: ProviderVocabulary {
    /// The id as OpenAI's API spells it.
    public let rawValue: String

    /// Creates an id from OpenAI's spelling of it.
    ///
    /// - Parameter rawValue: The id, such as `"gpt-6-luna"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension OpenAIModelID {
    /// Whether a model that answered, as its answer names it, is this one: the same id, or a dated snapshot of it,
    /// such as `gpt-5-nano-2025-08-07` for `gpt-5-nano`.
    func names(_ answeringModel: String) -> Bool {
        answeringModel == rawValue || answeringModel.wholeMatch(of: /(.+)-\d{4}-\d{2}-\d{2}/).map { String($0.1) == rawValue } == true
    }
}
