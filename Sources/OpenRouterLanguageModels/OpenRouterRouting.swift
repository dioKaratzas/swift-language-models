public import Foundation
public import LanguageModels

/// Which of a model's hosts OpenRouter may send requests to, and in what order.
///
/// OpenRouter calls the hosts that serve a model its providers, such as the model's maker or Amazon Bedrock, so the
/// settings that name hosts, such as ``allowedProviders``, keep OpenRouter's word, as does the request's `provider`
/// object that the routing becomes.
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

    /// Whether `sort` ranks each model's hosts on their own or the hosts of every model together, for a request
    /// that can fall back to other models, as a router's requests and those of a model with
    /// ``OpenRouterLanguageModel/fallbacks`` do.
    public enum SortPartition: String, Sendable, Hashable {
        /// Each model's hosts are ranked on their own, so a fallback model's hosts come after those of the model
        /// picked first. OpenRouter's default.
        case byModel = "model"

        /// The hosts of every model are ranked together, so a fallback model's host comes first when it ranks higher.
        case acrossModels = "none"
    }

    /// A suffix on the model id that changes how OpenRouter routes the request, such as `nitro`.
    ///
    /// ``nitro`` and ``floor`` rank the model's hosts and let the hosts of a service tier compete. A host of the tier
    /// serves the request only when it wins the ranking, and the request is billed at the rate of the tier that serves
    /// it, which can differ from the model's own price. Any other variant OpenRouter offers is valid too, written as its
    /// suffix without the colon.
    public struct Variant: ProviderVocabulary {
        /// `:nitro`, which ranks hosts by throughput and lets priority tiers compete. A priority host bills more.
        public static let nitro: Self = "nitro"

        /// `:floor`, which ranks hosts by price and lets flex tiers compete. A flex host bills less.
        public static let floor: Self = "floor"

        /// The suffix without its colon, as OpenRouter's model ids spell it.
        public let rawValue: String

        /// Creates a variant from its suffix.
        ///
        /// - Parameter rawValue: The suffix without its colon, such as `"nitro"`.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Creates a variant from a string literal of its suffix.
        ///
        /// - Parameter value: The suffix without its colon, such as `"nitro"`.
        public init(stringLiteral value: String) {
            self.init(rawValue: value)
        }

        /// The raw value, so printing a value shows OpenRouter's spelling of it.
        public var description: String { rawValue }
    }

    /// The most to pay for a request, in US dollars.
    ///
    /// A host that charges more for any price that's set isn't used, and the request fails when no host qualifies.
    public struct MaximumPrice: Sendable, Hashable {
        /// The most to pay per million prompt tokens.
        public var prompt: Decimal?

        /// The most to pay per million generated tokens.
        public var completion: Decimal?

        /// The most to pay per image.
        public var image: Decimal?

        /// The most to pay per unit of audio.
        public var audio: Decimal?

        /// The most to pay per request, for hosts that charge by the request.
        public var request: Decimal?

        /// Creates price limits.
        ///
        /// - Parameters:
        ///   - prompt: The most to pay per million prompt tokens.
        ///   - completion: The most to pay per million generated tokens.
        ///   - image: The most to pay per image.
        ///   - audio: The most to pay per unit of audio.
        ///   - request: The most to pay per request.
        public init(
            prompt: Decimal? = nil,
            completion: Decimal? = nil,
            image: Decimal? = nil,
            audio: Decimal? = nil,
            request: Decimal? = nil
        ) {
            self.prompt = prompt
            self.completion = completion
            self.image = image
            self.audio = audio
            self.request = request
        }

        /// The `max_price` object, each price as a decimal string so it's sent exactly, or `nil` when none is set.
        var json: JSONValue? {
            func price(_ price: Decimal?) -> JSONValue? { price.map { .string($0.description) } }
            let json: JSONObject = [
                "prompt": price(prompt),
                "completion": price(completion),
                "image": price(image),
                "audio": price(audio),
                "request": price(request),
            ]
            return json.members.isEmpty ? nil : .object(json)
        }
    }

    /// Thresholds on a host's recent performance, each met by a share of its requests, such as the median, `p50`.
    ///
    /// A host is preferred only when it meets every threshold that's set. One that misses them is tried later but can
    /// still serve the request. Setting only `p50` is the same as OpenRouter's single-number form.
    public struct Percentiles<Value: Sendable & Hashable>: Sendable, Hashable {
        /// The threshold that half of the host's requests meet.
        public var p50: Value?

        /// The threshold that three quarters of the host's requests meet.
        public var p75: Value?

        /// The threshold that 90% of the host's requests meet.
        public var p90: Value?

        /// The threshold that 99% of the host's requests meet.
        public var p99: Value?

        /// Creates thresholds.
        ///
        /// - Parameters:
        ///   - p50: The threshold that half of the host's requests meet.
        ///   - p75: The threshold that three quarters of the host's requests meet.
        ///   - p90: The threshold that 90% of the host's requests meet.
        ///   - p99: The threshold that 99% of the host's requests meet.
        public init(p50: Value? = nil, p75: Value? = nil, p90: Value? = nil, p99: Value? = nil) {
            self.p50 = p50
            self.p75 = p75
            self.p90 = p90
            self.p99 = p99
        }

        /// The thresholds as one number when only `p50` is set, otherwise as an object, or `nil` when none is set.
        func json(_ number: (Value) -> Double) -> JSONValue? {
            func threshold(_ value: Value?) -> JSONValue? { value.map { .number(number($0)) } }
            if p75 == nil, p90 == nil, p99 == nil { return threshold(p50) }
            return ["p50": threshold(p50), "p75": threshold(p75), "p90": threshold(p90), "p99": threshold(p99)]
        }
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
    /// When `nil`, requests with tools, server tools or a response schema require them, so a host that would ignore
    /// the tools or the schema isn't used.
    public var requiresParameters: Bool?

    /// Whether hosts may store prompts and train on them.
    public var dataCollection: DataCollection?

    /// Whether to use only hosts that retain no prompts.
    public var requiresZeroDataRetention: Bool?

    /// Whether to use only models whose authors allow training other models on their output.
    public var requiresDistillableText: Bool?

    /// How to rank hosts when no `order` is set.
    public var sort: OpenRouterProviderSort?

    /// Whether `sort` ranks each model's hosts on their own or the hosts of every model together.
    public var sortPartition: SortPartition?

    /// The model weight precisions to allow, such as `fp8`.
    public var quantizations: [OpenRouterQuantization]?

    /// The most to pay for a request. Unlike the preferred throughput and latency, it fails a request that no host
    /// can serve within it.
    public var maximumPrice: MaximumPrice?

    /// The throughput, in tokens per second, at or above which a host is preferred.
    public var preferredMinimumThroughput: Percentiles<Double>?

    /// The latency at or below which a host is preferred.
    public var preferredMaximumLatency: Percentiles<Duration>?

    /// A suffix on the model id, such as `:nitro` or `:floor`, that ranks the model's hosts and lets a service tier
    /// compete.
    ///
    /// The request names the model with the suffix, and each of its ``OpenRouterLanguageModel/fallbacks`` too, since
    /// the routing applies to whichever model answers. The models' details, such as their context sizes and
    /// parameters, stay those of the catalog models. `nitro` and `floor` can change what a request costs. An `order`
    /// replaces the ranking and keeps the tier's hosts out, and a ``OpenRouterOptions/serviceTier`` of
    /// ``OpenRouterServiceTier/default`` keeps the ranking but keeps the tier's hosts out.
    public var variant: Variant?

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
    ///   - requiresDistillableText: Whether to use only models whose authors allow training other models on their
    ///     output.
    ///   - sort: How to rank hosts when no `order` is set.
    ///   - sortPartition: Whether `sort` ranks each model's hosts on their own or the hosts of every model together.
    ///   - quantizations: The model weight precisions to allow.
    ///   - maximumPrice: The most to pay for a request.
    ///   - preferredMinimumThroughput: The throughput, in tokens per second, at or above which a host is preferred.
    ///   - preferredMaximumLatency: The latency at or below which a host is preferred.
    ///   - variant: A suffix on the model id that ranks the model's hosts and lets a service tier compete.
    public init(
        order: [OpenRouterProviderName]? = nil,
        allowedProviders: [OpenRouterProviderName]? = nil,
        ignoredProviders: [OpenRouterProviderName]? = nil,
        allowsFallbacks: Bool? = nil,
        requiresParameters: Bool? = nil,
        dataCollection: DataCollection? = nil,
        requiresZeroDataRetention: Bool? = nil,
        requiresDistillableText: Bool? = nil,
        sort: OpenRouterProviderSort? = nil,
        sortPartition: SortPartition? = nil,
        quantizations: [OpenRouterQuantization]? = nil,
        maximumPrice: MaximumPrice? = nil,
        preferredMinimumThroughput: Percentiles<Double>? = nil,
        preferredMaximumLatency: Percentiles<Duration>? = nil,
        variant: Variant? = nil
    ) {
        self.order = order
        self.allowedProviders = allowedProviders
        self.ignoredProviders = ignoredProviders
        self.allowsFallbacks = allowsFallbacks
        self.requiresParameters = requiresParameters
        self.dataCollection = dataCollection
        self.requiresZeroDataRetention = requiresZeroDataRetention
        self.requiresDistillableText = requiresDistillableText
        self.sort = sort
        self.sortPartition = sortPartition
        self.quantizations = quantizations
        self.maximumPrice = maximumPrice
        self.preferredMinimumThroughput = preferredMinimumThroughput
        self.preferredMaximumLatency = preferredMaximumLatency
        self.variant = variant
    }

    /// The `provider` object of OpenRouter's request.
    ///
    /// - Parameter needsParameters: Whether the request needs its parameters honored when the routing doesn't say.
    /// - Returns: The object, or `nil` when every setting keeps OpenRouter's default.
    func json(needsParameters: Bool) -> JSONValue? {
        func names(_ names: [OpenRouterProviderName]?) -> JSONValue? { names.map { .array($0.map { .string($0.rawValue) }) } }
        var requiresParameters = self.requiresParameters
        if requiresParameters == nil, needsParameters {
            requiresParameters = true
        }
        let json: JSONObject = [
            "order": names(order),
            "only": names(allowedProviders),
            "ignore": names(ignoredProviders),
            "allow_fallbacks": allowsFallbacks.map(JSONValue.bool),
            "require_parameters": requiresParameters.map(JSONValue.bool),
            "data_collection": dataCollection.map { .string($0.rawValue) },
            "zdr": requiresZeroDataRetention.map(JSONValue.bool),
            "enforce_distillable_text": requiresDistillableText.map(JSONValue.bool),
            "sort": sortJSON,
            "quantizations": quantizations.map { .array($0.map { .string($0.rawValue) }) },
            "max_price": maximumPrice?.json,
            "preferred_min_throughput": preferredMinimumThroughput?.json { $0 },
            "preferred_max_latency": preferredMaximumLatency?.json { $0 / .seconds(1) },
        ]
        return json.members.isEmpty ? nil : .object(json)
    }

    /// The model id a request names for the model or one of its fallbacks: the catalog model's id, with the variant's
    /// suffix when one is set.
    func modelID(for id: OpenRouterModelID) -> String {
        guard let variant else { return id.rawValue }
        return "\(id.rawValue):\(variant.rawValue)"
    }

    /// The ranking's name, or an object with the ranking and its partition when a partition is set.
    private var sortJSON: JSONValue? {
        let ranking = sort.map { JSONValue.string($0.rawValue) }
        guard let sortPartition else { return ranking }
        return ["by": ranking, "partition": .string(sortPartition.rawValue)]
    }
}
