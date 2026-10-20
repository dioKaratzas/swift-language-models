package import FoundationModels

extension LanguageModelCapabilities {
    /// The capabilities in the set, in a fixed order, so a test can compare them with one expectation.
    package var listed: [Capability] {
        [.toolCalling, .guidedGeneration, .reasoning, .vision].filter(contains)
    }
}
