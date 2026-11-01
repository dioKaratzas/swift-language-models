public import LanguageModels

/// An OpenRouter model id, such as `typesafe/jev-router`.
///
/// A distinct type, so text that isn't an OpenRouter id, such as a display name or another provider's id, can't be
/// passed by mistake.
///
/// To make ids from strings, name the initializer in full, since a bare `OpenRouterModelID.init` could also mean the
/// string-literal one:
///
/// ```swift
/// let ids = savedIDs.map(OpenRouterModelID.init(rawValue:))
/// ```
public struct OpenRouterModelID: ProviderVocabulary {
    /// The id as OpenRouter's API spells it.
    public let rawValue: String

    /// Creates an id from OpenRouter's spelling of it.
    ///
    /// - Parameter rawValue: The id, such as `"typesafe/jev-router"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension OpenRouterModelID {
    /// Whether the id names an Anthropic model, or an alias of one, such as `~anthropic/claude-haiku-latest`.
    var isAnthropic: Bool { vendor == "anthropic" }

    /// The vendors whose structured outputs, by their own documentation, reject schema constraints such as `minimum`
    /// and `maxItems`, so a request that may reach one of their models sends the portable schema from the start.
    static let vendorsRejectingSchemaConstraints: Set<Substring> = ["anthropic"]

    /// Whether the id names a model whose structured outputs reject schema constraints, or an alias of one.
    var rejectsSchemaConstraints: Bool { Self.vendorsRejectingSchemaConstraints.contains(vendor) }

    /// The vendor the id starts with, such as `anthropic` for `anthropic/claude-haiku-5.5` and for its alias
    /// `~anthropic/claude-haiku-latest`.
    private var vendor: Substring {
        rawValue.drop { $0 == "~" }.prefix { $0 != "/" }
    }
}
