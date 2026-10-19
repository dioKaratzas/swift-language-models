import LanguageModels

/// Which of a model's hosts OpenRouter may send requests to, and in what order.
///
/// Every setting left `nil` keeps OpenRouter's default. Setting an `order` turns off OpenRouter's sticky routing, so
/// requests of one session may reach a host that hasn't cached their prompt.
public struct OpenRouterRouting: Sendable, Hashable {
    /// Whether hosts may store prompts and train on them.
    public enum DataCollection: String, Sendable, Hashable {
        /// Any host, including those that store prompts and may train on them. OpenRouter's default.
        case allow

        /// Only hosts that don't collect prompts.
        case deny
    }

    /// The hosts to try first, in order, by name or slug, such as `"Anthropic"` or `"amazon-bedrock"`.
    public var order: [OpenRouterProviderName]?

    /// The only hosts to use.
    public var allowedProviders: [OpenRouterProviderName]?

    /// Hosts never to use.
    public var ignoredProviders: [OpenRouterProviderName]?

    /// Whether to fall back to other hosts when the chosen ones are unavailable.
    public var allowsFallbacks: Bool?

    /// Whether to use only hosts that support every parameter a request sends.
    ///
    /// When `nil`, requests with tools or a response schema require them, so a host that would ignore the tools or
    /// the schema isn't used.
    public var requiresParameters: Bool?

    /// Whether hosts may store prompts and train on them.
    public var dataCollection: DataCollection?

    /// Whether to use only hosts that retain no prompts.
    public var requiresZeroDataRetention: Bool?

    /// How to rank hosts when no `order` is set.
    public var sort: OpenRouterProviderSort?

    /// The model weight precisions to allow, such as `fp8`.
    public var quantizations: [OpenRouterQuantization]?

    /// Creates routing preferences.
    ///
    /// - Parameters:
    ///   - order: The hosts to try first, in order.
    ///   - allowedProviders: The only hosts to use.
    ///   - ignoredProviders: Hosts never to use.
    ///   - allowsFallbacks: Whether to fall back to other hosts when the chosen ones are unavailable.
    ///   - requiresParameters: Whether to use only hosts that support every parameter a request sends.
    ///   - dataCollection: Whether hosts may store prompts and train on them.
    ///   - requiresZeroDataRetention: Whether to use only hosts that retain no prompts.
    ///   - sort: How to rank hosts when no `order` is set.
    ///   - quantizations: The model weight precisions to allow.
    public init(
        order: [OpenRouterProviderName]? = nil,
        allowedProviders: [OpenRouterProviderName]? = nil,
        ignoredProviders: [OpenRouterProviderName]? = nil,
        allowsFallbacks: Bool? = nil,
        requiresParameters: Bool? = nil,
        dataCollection: DataCollection? = nil,
        requiresZeroDataRetention: Bool? = nil,
        sort: OpenRouterProviderSort? = nil,
        quantizations: [OpenRouterQuantization]? = nil
    ) {
        self.order = order
        self.allowedProviders = allowedProviders
        self.ignoredProviders = ignoredProviders
        self.allowsFallbacks = allowsFallbacks
        self.requiresParameters = requiresParameters
        self.dataCollection = dataCollection
        self.requiresZeroDataRetention = requiresZeroDataRetention
        self.sort = sort
        self.quantizations = quantizations
    }

    /// The `provider` object of OpenRouter's request.
    ///
    /// - Parameter needsParameters: Whether the request needs its parameters honored when the routing doesn't say.
    /// - Returns: The object, or `nil` when every setting keeps OpenRouter's default.
    func json(needsParameters: Bool) -> JSONValue? {
        let names = { (names: [OpenRouterProviderName]?) in names.map { JSONValue.array($0.map { .string($0.rawValue) }) } }
        let json: JSONObject = [
            "order": names(order),
            "only": names(allowedProviders),
            "ignore": names(ignoredProviders),
            "allow_fallbacks": allowsFallbacks.map(JSONValue.bool),
            "require_parameters": (requiresParameters ?? (needsParameters ? true : nil)).map(JSONValue.bool),
            "data_collection": dataCollection.map { .string($0.rawValue) },
            "zdr": requiresZeroDataRetention.map(JSONValue.bool),
            "sort": sort.map { .string($0.rawValue) },
            "quantizations": quantizations.map { .array($0.map { .string($0.rawValue) }) },
        ]
        return json.members.isEmpty ? nil : .object(json)
    }
}
