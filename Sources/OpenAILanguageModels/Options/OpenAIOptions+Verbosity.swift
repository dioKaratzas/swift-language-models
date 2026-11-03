public import LanguageModels

extension OpenAIOptions {
    /// How long and detailed a model's answers are, from `low` to `high`.
    public struct Verbosity: ProviderVocabulary {
        /// Short, concise answers.
        public static let low: Self = "low"

        /// Answers of the usual length, the model's default.
        public static let medium: Self = "medium"

        /// Longer, more detailed answers.
        public static let high: Self = "high"

        /// The level's name in OpenAI's API.
        public let rawValue: String

        /// Creates a level from its name in OpenAI's API.
        ///
        /// - Parameter rawValue: The name, such as `"low"`.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
