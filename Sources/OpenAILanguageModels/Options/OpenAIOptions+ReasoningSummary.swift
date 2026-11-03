public import LanguageModels

extension OpenAIOptions {
    /// How much of its reasoning a model summarizes for the answer's reasoning entry.
    public struct ReasoningSummary: ProviderVocabulary {
        /// The most detailed summary the model writes.
        public static let auto: Self = "auto"

        /// A short summary.
        public static let concise: Self = "concise"

        /// A detailed summary.
        public static let detailed: Self = "detailed"

        /// The summary's name in OpenAI's API.
        public let rawValue: String

        /// Creates a summary from its name in OpenAI's API.
        ///
        /// - Parameter rawValue: The name, such as `"auto"`.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
