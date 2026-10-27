public import FoundationModels

extension Efforts {
    /// The effort of a model whose reasoning level can't be chosen, which has no levels.
    ///
    /// A model that doesn't reason has this effort, and so does a model that reasons at a level it picks itself. For
    /// a model that reasons, `reasoningLevel(_:)` still turns reasoning on or off.
    ///
    /// Like the other effort types, it's `Codable`, so code that stores an effort works with any model. Decoding
    /// always fails, because there's no value to decode.
    public enum Unsupported: ModelEffort, CaseIterable, Codable {
        /// Never called, because the type has no values.
        public var reasoningLevel: ContextOptions.ReasoningLevel {
            switch self {}
        }

        /// Fails, because the type has no values.
        ///
        /// - Throws: `DecodingError.dataCorrupted`.
        public init(from decoder: any Decoder) throws {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Efforts.Unsupported has no values.")
            )
        }

        /// Never called, because the type has no values.
        public func encode(to encoder: any Encoder) throws {
            switch self {}
        }
    }
}
