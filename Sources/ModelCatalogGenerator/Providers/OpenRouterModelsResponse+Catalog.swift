extension OpenRouterModelsResponse {
    /// The variant suffix of models that work only through OpenRouter's Batch API, not chat completions.
    private static let batchSuffix = ":batch"

    /// The models in catalog form.
    ///
    /// A model whose id ends in `:batch` is left out, because it works only through the Batch API. A model that
    /// accepts every effort lists `everyEffort`, and a model that doesn't list its efforts gets none, as its effort
    /// can't be chosen. A model whose reasoning is mandatory can't take `none`, so it never lists it. A default effort
    /// the model doesn't list is dropped. A negative price, which OpenRouter uses for models priced per request,
    /// becomes no price, and an override that changes no kept price is dropped.
    ///
    /// - Parameter everyEffort: Every effort word, highest first.
    /// - Returns: The models, in OpenRouter's order.
    func catalogModels(everyEffort: [String]) -> [CatalogModel] {
        data.filter { !$0.id.hasSuffix(Self.batchSuffix) }.map { model in
            let isReasoningMandatory = model.reasoning?.mandatory ?? false
            let parameters = Set(model.supportedParameters ?? []).sorted()
            var efforts =
                switch model.reasoning?.supportedEfforts {
                case .listed(let words)?: words
                case .any?: everyEffort
                case .unlisted?, nil: [String]()
                }
            if isReasoningMandatory { efforts.removeAll { $0 == "none" } }
            return CatalogModel(
                id: model.id,
                displayName: model.name,
                aliasTarget: model.aliasTarget?.slug,
                releasedAt: model.created,
                knowledgeCutoff: model.knowledgeCutoff,
                expirationDate: model.expirationDate,
                contextSize: model.contextLength,
                maximumOutputTokens: model.topProvider?.maxCompletionTokens,
                inputModalities: Set(model.architecture.inputModalities).sorted(),
                outputModalities: Set(model.architecture.outputModalities).sorted(),
                supportedParameters: parameters,
                reasoningEfforts: efforts,
                defaultReasoningEffort: model.reasoning?.defaultEffort.flatMap { efforts.contains($0) ? $0 : nil },
                reasoning: Self.reasoning(
                    isMandatory: isReasoningMandatory,
                    isEnabledByDefault: model.reasoning?.defaultEnabled == true,
                    parameters: parameters
                ),
                pricing: model.pricing.flatMap(Self.pricing)
            )
        }
    }

    /// Whether and when a model reasons: mandatory reasoning wins, and otherwise a model reasons only when it takes
    /// the `reasoning` parameter, which turns reasoning on or off.
    ///
    /// - Parameters:
    ///   - isMandatory: Whether the model always reasons.
    ///   - isEnabledByDefault: Whether the model reasons when a request doesn't say.
    ///   - parameters: The request parameters the model takes.
    /// - Returns: The model's reasoning.
    static func reasoning(isMandatory: Bool, isEnabledByDefault: Bool, parameters: [String]) -> CatalogReasoning {
        if isMandatory { return .mandatory }
        return parameters.contains("reasoning") ? .optional(enabledByDefault: isEnabledByDefault) : .unsupported
    }

    private static func pricing(_ pricing: Model.Pricing) -> CatalogModel.Pricing? {
        guard let prompt = price(pricing.prompt), let completion = price(pricing.completion) else { return nil }
        let overrides = (pricing.overrides ?? []).map(override).filter(\.setsPrice)
        return CatalogModel.Pricing(
            prompt: prompt,
            completion: completion,
            cacheRead: price(pricing.inputCacheRead),
            cacheWrite: price(pricing.inputCacheWrite),
            cacheWriteOneHour: price(pricing.inputCacheWrite1H),
            reasoning: price(pricing.internalReasoning),
            audio: price(pricing.audio),
            image: price(pricing.image),
            request: price(pricing.request),
            webSearch: price(pricing.webSearch),
            overrides: overrides.isEmpty ? nil : overrides
        )
    }

    private static func override(_ override: Model.Pricing.Override) -> CatalogModel.Pricing.Override {
        CatalogModel.Pricing.Override(
            // The threshold counts whole tokens, so a fraction rounds down without changing which prompts exceed it.
            promptTokensAbove: override.minPromptTokens.map { Int($0.rounded(.down)) },
            weekdays: override.utcDays,
            startTime: override.utcStart,
            endTime: override.utcEnd,
            prompt: price(override.prompt),
            completion: price(override.completion),
            cacheRead: price(override.inputCacheRead),
            cacheWrite: price(override.inputCacheWrite),
            cacheWriteOneHour: price(override.inputCacheWrite1H),
            audio: price(override.audio)
        )
    }

    private static func price(_ text: String?) -> String? {
        text.flatMap { $0.hasPrefix("-") ? nil : $0 }
    }
}
