public import FoundationModels

extension Efforts {
    /// The effort of a model that doesn't reason, which has no levels.
    public enum Unsupported: ModelEffort, CaseIterable {
        /// Never called, because the type has no values.
        public var reasoningLevel: ContextOptions.ReasoningLevel {
            switch self {}
        }
    }
}
