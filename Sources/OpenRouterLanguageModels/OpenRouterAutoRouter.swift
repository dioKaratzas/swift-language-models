public import LanguageModels

/// How OpenRouter's Auto Router picks the model that answers a request to `openrouter/auto` or `openrouter/auto-beta`.
///
/// The router sorts each prompt into a kind of task, and picks from the models people spend the most on for that kind
/// of task. The two routers read the same settings, each under its own plugin id, so a request sends them under the id
/// of the router it goes to, and a request to any other model leaves them out. Every setting left `nil` keeps the
/// router's default, or the one saved for the account.
public struct OpenRouterAutoRouter: Sendable, Hashable {
    /// A band of the models people use for a kind of task, by their cost.
    ///
    /// Each tier holds a fifth of the models, from `low`, the cheapest, to `max`, the most capable at any price. A tier
    /// isn't a ceiling: it leaves out models cheaper than its band as well as dearer ones.
    public struct CostTier: ProviderVocabulary {
        /// The cheapest capable models, near what the router picks when no tier is set.
        public static let low: Self = "low"

        /// The second band by cost.
        public static let medium: Self = "medium"

        /// The middle band by cost.
        public static let high: Self = "high"

        /// The fourth band by cost.
        public static let xhigh: Self = "xhigh"

        /// The most capable models, whatever their price.
        public static let max: Self = "max"

        /// The tier's name in OpenRouter's API.
        public let rawValue: String

        /// Creates a tier from its name in OpenRouter's API.
        ///
        /// - Parameter rawValue: The name, such as `"medium"`.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Creates a tier from a string literal of its name in OpenRouter's API.
        ///
        /// - Parameter value: The name, such as `"medium"`.
        public init(stringLiteral value: String) {
            self.init(rawValue: value)
        }

        /// The raw value, so printing a value shows OpenRouter's spelling of it.
        public var description: String { rawValue }
    }

    /// The models the router may pick from, by id or by a pattern such as `anthropic/*` or `openai/gpt-5*`.
    public var allowedModels: [String]?

    /// The models the router never picks, by id or pattern, even when `allowedModels` matches them. A request whose
    /// lists leave no model fails.
    public var excludedModels: [String]?

    /// The band of models by cost to pick from.
    public var costTier: CostTier?

    /// Creates Auto Router settings.
    ///
    /// - Parameters:
    ///   - allowedModels: The models the router may pick from, by id or pattern.
    ///   - excludedModels: The models the router never picks, by id or pattern.
    ///   - costTier: The band of models by cost to pick from.
    public init(allowedModels: [String]? = nil, excludedModels: [String]? = nil, costTier: CostTier? = nil) {
        self.allowedModels = allowedModels
        self.excludedModels = excludedModels
        self.costTier = costTier
    }

    /// The router's entry in the request's `plugins`, under the plugin id the router reads, such as `auto-router`.
    func json(pluginID: String) -> JSONValue {
        let patterns = { (patterns: [String]?) in patterns.map { JSONValue.array($0.map(JSONValue.string)) } }
        return [
            "id": .string(pluginID),
            "allowed_models": patterns(allowedModels),
            "excluded_models": patterns(excludedModels),
            "cost_tier": costTier.map { .string($0.rawValue) },
        ]
    }
}
