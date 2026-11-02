public import LanguageModels

extension OpenRouterResponseMetadata {
    /// How OpenRouter picked the model and host for a request, as the router's report names it, such as ``fallback``.
    ///
    /// Any strategy OpenRouter reports is valid, with or without a static member.
    public struct RoutingStrategy: ProviderVocabulary {
        /// OpenRouter sent the request to a host of the model it names.
        public static let direct: Self = "direct"

        /// The Auto Router, `openrouter/auto`, picked the model.
        public static let auto: Self = "auto"

        /// OpenRouter's `free` routing.
        public static let free: Self = "free"

        /// OpenRouter's `latest` routing.
        public static let latest: Self = "latest"

        /// The request named an alias, which OpenRouter resolved to the model it stands for.
        public static let alias: Self = "alias"

        /// An earlier host or model failed, and OpenRouter fell back to another.
        public static let fallback: Self = "fallback"

        /// The Pareto router, such as `openrouter/pareto-code`, picked the model.
        public static let pareto: Self = "pareto"

        /// OpenRouter's `bodybuilder` routing.
        public static let bodybuilder: Self = "bodybuilder"

        /// OpenRouter's `fusion` routing.
        public static let fusion: Self = "fusion"

        /// The strategy as the router's report spells it.
        public let rawValue: String

        /// Creates a strategy from the router's spelling of it.
        ///
        /// - Parameter rawValue: The strategy, such as `"fallback"`.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
