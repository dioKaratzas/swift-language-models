public import LanguageModels

extension OpenRouterOptions {
    /// How OpenRouter's Pareto router picks the coding model that answers a request to `openrouter/pareto-code`.
    ///
    /// The router picks from the top coding models: by quality tier, the cheapest available model of the tier, or its
    /// fastest with the ``OpenRouterRouting/Variant/nitro`` variant; or by price, the best-scoring model at or below
    /// ``maximumPromptPrice``. A request to any other model leaves the settings out. Every setting left `nil` keeps the
    /// router's default.
    public struct ParetoRouter: Sendable, Hashable {
        /// The price the router compares against ``OpenRouterOptions/ParetoRouter/maximumPromptPrice``.
        public struct PriceSource: ProviderVocabulary {
            /// Each model's listed prompt price. The router's default.
            public static let prompt: Self = "prompt"

            /// Each model's prompt price weighted by its traffic, or its listed price when it has none.
            public static let weightedAverage: Self = "weighted_avg"

            /// The source's name in OpenRouter's API.
            public let rawValue: String

            /// Creates a source from its name in OpenRouter's API.
            ///
            /// - Parameter rawValue: The name, such as `"weighted_avg"`.
            public init(rawValue: String) {
                self.rawValue = rawValue
            }
        }

        /// The lowest coding score, from 0 to 1, of the models to pick from.
        ///
        /// The score picks a tier: 0.66 and up is the top coding models, 0.33 and up strong recent flagships, and below
        /// that capable coders above the median. When `nil`, the router picks from the top tier. ``maximumPromptPrice``
        /// takes over when it's set.
        public var minimumCodingScore: Double?

        /// The most a picked model's prompt may cost, in US dollars per million tokens.
        ///
        /// The router then picks the best-scoring model at or below it, and a request that no model fits fails.
        public var maximumPromptPrice: Double?

        /// The price ``maximumPromptPrice`` is compared against.
        public var priceSource: PriceSource?

        /// Creates Pareto router settings.
        ///
        /// - Parameters:
        ///   - minimumCodingScore: The lowest coding score, from 0 to 1, of the models to pick from.
        ///   - maximumPromptPrice: The most a picked model's prompt may cost, in US dollars per million tokens.
        ///   - priceSource: The price `maximumPromptPrice` is compared against.
        public init(minimumCodingScore: Double? = nil, maximumPromptPrice: Double? = nil, priceSource: PriceSource? = nil) {
            self.minimumCodingScore = minimumCodingScore
            self.maximumPromptPrice = maximumPromptPrice
            self.priceSource = priceSource
        }

        /// The router's entry in the request's `plugins`.
        var json: JSONValue {
            [
                "id": "pareto-router",
                "min_coding_score": minimumCodingScore.map(JSONValue.number),
                "max_price": maximumPromptPrice.map(JSONValue.number),
                "price_source": priceSource.map(\.json),
            ]
        }
    }
}
