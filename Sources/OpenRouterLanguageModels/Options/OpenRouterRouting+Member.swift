import Foundation

extension OpenRouterRouting {
    /// The `provider` object of OpenRouter's request.
    ///
    /// - Parameter needsParameters: Whether the request needs its parameters honored when the routing doesn't say.
    /// - Returns: The object, or `nil` when every setting keeps OpenRouter's default.
    func member(needsParameters: Bool) -> Member? {
        let parameterSupport = self.parameterSupport == .automatic && needsParameters ? .required : self.parameterSupport
        let member = Member(routing: self, parameterSupport: parameterSupport)
        return member.isEmpty ? nil : member
    }

    /// The `provider` object of OpenRouter's request: each setting that doesn't keep OpenRouter's default, in the
    /// order OpenRouter's requests have always sent them.
    struct Member: Encodable {
        let routing: OpenRouterRouting

        /// Whether hosts must take every parameter the request sends, after the request's own needs.
        let parameterSupport: Requirement

        private var sort: SortMember? { SortMember(sort: routing.sort, partition: routing.sortPartition) }
        private var maximumPrice: Prices? { routing.maximumPrice.flatMap(Prices.init) }
        private var minimumThroughput: Thresholds? { routing.preferredMinimumThroughput.flatMap { Thresholds($0) { $0 } } }
        private var maximumLatency: Thresholds? { routing.preferredMaximumLatency.flatMap { Thresholds($0) { $0 / .seconds(1) } } }

        /// Whether every setting keeps OpenRouter's default, so the object would be empty.
        fileprivate var isEmpty: Bool {
            routing.order == nil && routing.allowedProviders == nil && routing.excludedProviders == nil
                && routing.fallbackProviders.value == nil && parameterSupport.value == nil && routing.dataCollection == nil
                && routing.zeroDataRetention.value == nil && routing.distillableText.value == nil && sort == nil
                && routing.quantizations == nil && maximumPrice == nil && minimumThroughput == nil && maximumLatency == nil
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: Key.self)
            try container.encodeIfPresent(routing.order, forKey: .order)
            try container.encodeIfPresent(routing.allowedProviders, forKey: .only)
            try container.encodeIfPresent(routing.excludedProviders, forKey: .ignore)
            try container.encodeIfPresent(routing.fallbackProviders.value, forKey: .allowFallbacks)
            try container.encodeIfPresent(parameterSupport.value, forKey: .requireParameters)
            try container.encodeIfPresent(routing.dataCollection, forKey: .dataCollection)
            try container.encodeIfPresent(routing.zeroDataRetention.value, forKey: .zeroDataRetention)
            try container.encodeIfPresent(routing.distillableText.value, forKey: .distillableText)
            try container.encodeIfPresent(sort, forKey: .sort)
            try container.encodeIfPresent(routing.quantizations, forKey: .quantizations)
            try container.encodeIfPresent(maximumPrice, forKey: .maximumPrice)
            try container.encodeIfPresent(minimumThroughput, forKey: .minimumThroughput)
            try container.encodeIfPresent(maximumLatency, forKey: .maximumLatency)
        }

        private enum Key: String, CodingKey {
            case order
            case only
            case ignore
            case allowFallbacks = "allow_fallbacks"
            case requireParameters = "require_parameters"
            case dataCollection = "data_collection"
            case zeroDataRetention = "zdr"
            case distillableText = "enforce_distillable_text"
            case sort
            case quantizations
            case maximumPrice = "max_price"
            case minimumThroughput = "preferred_min_throughput"
            case maximumLatency = "preferred_max_latency"
        }
    }

    /// The ranking's name, or an object with the ranking and its partition when a partition is set.
    private struct SortMember: Encodable {
        let sort: Sort?
        let partition: SortPartition?

        init?(sort: Sort?, partition: SortPartition?) {
            guard sort != nil || partition != nil else { return nil }
            self.sort = sort
            self.partition = partition
        }

        func encode(to encoder: any Encoder) throws {
            guard let partition else {
                var container = encoder.singleValueContainer()
                try container.encode(sort)
                return
            }
            var container = encoder.container(keyedBy: Key.self)
            try container.encodeIfPresent(sort, forKey: .by)
            try container.encode(partition, forKey: .partition)
        }

        private enum Key: String, CodingKey {
            case by
            case partition
        }
    }

    /// The `max_price` object, each price as a decimal string so it's sent exactly.
    private struct Prices: Encodable {
        let price: MaximumPrice

        /// The prices, or `nil` when none is set.
        init?(_ price: MaximumPrice) {
            guard [price.prompt, price.completion, price.image, price.audio, price.request].contains(where: { $0 != nil }) else {
                return nil
            }
            self.price = price
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: Key.self)
            try container.encodeIfPresent(price.prompt?.description, forKey: .prompt)
            try container.encodeIfPresent(price.completion?.description, forKey: .completion)
            try container.encodeIfPresent(price.image?.description, forKey: .image)
            try container.encodeIfPresent(price.audio?.description, forKey: .audio)
            try container.encodeIfPresent(price.request?.description, forKey: .request)
        }

        private enum Key: String, CodingKey {
            case prompt
            case completion
            case image
            case audio
            case request
        }
    }

    /// Thresholds as one number when only `p50` is set, otherwise as an object.
    private struct Thresholds: Encodable {
        let p50: Double?
        let p75: Double?
        let p90: Double?
        let p99: Double?

        /// The thresholds as numbers, or `nil` when none is set.
        init?<Value>(_ percentiles: Percentiles<Value>, number: (Value) -> Double) {
            p50 = percentiles.p50.map(number)
            p75 = percentiles.p75.map(number)
            p90 = percentiles.p90.map(number)
            p99 = percentiles.p99.map(number)
            guard p50 != nil || p75 != nil || p90 != nil || p99 != nil else { return nil }
        }

        func encode(to encoder: any Encoder) throws {
            if p75 == nil, p90 == nil, p99 == nil {
                var container = encoder.singleValueContainer()
                try container.encode(p50)
                return
            }
            var container = encoder.container(keyedBy: Key.self)
            try container.encodeIfPresent(p50, forKey: .p50)
            try container.encodeIfPresent(p75, forKey: .p75)
            try container.encodeIfPresent(p90, forKey: .p90)
            try container.encodeIfPresent(p99, forKey: .p99)
        }

        private enum Key: String, CodingKey {
            case p50
            case p75
            case p90
            case p99
        }
    }
}
