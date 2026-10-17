public import FoundationModels

extension Efforts {
    /// The effort of a model whose reasoning level can't be chosen, which has no levels.
    ///
    /// A model that doesn't reason has this effort, and so does a model that reasons at a level it picks itself. For
    /// a model that reasons, `reasoningLevel(_:)` still turns reasoning on or off.
    public enum Unsupported: ModelEffort, CaseIterable {
        /// Never called, because the type has no values.
        public var reasoningLevel: ContextOptions.ReasoningLevel {
            switch self {}
        }
    }
}
