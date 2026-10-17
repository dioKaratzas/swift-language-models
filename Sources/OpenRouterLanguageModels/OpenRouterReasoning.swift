/// Whether and when an OpenRouter model reasons.
public enum OpenRouterReasoning: Sendable, Hashable {
    /// The model doesn't reason.
    case unsupported

    /// The model reasons only when asked, or also by default, and a request can turn reasoning off.
    ///
    /// - Parameter enabledByDefault: Whether the model reasons when a request doesn't set a reasoning level.
    case optional(enabledByDefault: Bool)

    /// The model always reasons, so a request can't turn reasoning off.
    case mandatory
}
