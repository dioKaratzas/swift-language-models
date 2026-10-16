public import FoundationModels

/// A value that names a reasoning level for one set of models.
///
/// Conform an enum that lists exactly the levels a set of models accepts, so that passing any other level fails to
/// compile. `ContextOptions.ReasoningLevel` conforms too, for models whose levels are known only at runtime.
public protocol ModelEffort: Sendable, Equatable {
    /// The reasoning level this value asks for.
    var reasoningLevel: ContextOptions.ReasoningLevel { get }
}

extension ContextOptions.ReasoningLevel: ModelEffort {
    /// The level itself.
    public var reasoningLevel: Self { self }
}
