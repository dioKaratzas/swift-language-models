extension OpenRouterModelsResponse {
    /// The models in catalog form.
    ///
    /// A model that accepts every effort lists `everyEffort`, and a model that doesn't list its efforts gets none, as
    /// its effort can't be chosen. A model whose reasoning is mandatory can't take `none`, so it never lists it, and it
    /// reasons by default. A default effort the model doesn't list is dropped. A negative price, which OpenRouter uses
    /// for models priced per request, becomes no price, and an override that changes no kept price is dropped.
    ///
    /// - Parameter everyEffort: Every effort word, highest first.
    func catalogModels(everyEffort: [String]) -> [CatalogModel] {
        data.map { model in
            let isReasoningMandatory = model.reasoning?.mandatory ?? false
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
                inputModalities: model.architecture.inputModalities.sorted(),
                outputModalities: model.architecture.outputModalities.sorted(),
                supportedParameters: (model.supportedParameters ?? []).sorted(),
                reasoningEfforts: efforts,
                defaultReasoningEffort: model.reasoning?.defaultEffort.flatMap { efforts.contains($0) ? $0 : nil },
                isReasoningMandatory: isReasoningMandatory,
                reasonsByDefault: isReasoningMandatory || model.reasoning?.defaultEnabled == true,
                pricing: model.pricing.flatMap(Self.pricing)
            )
        }
    }

    private static func pricing(_ pricing: Model.Pricing) -> CatalogModel.Pricing? {
        guard let prompt = price(pricing.prompt), let completion = price(pricing.completion) else { return nil }
        let overrides = (pricing.overrides ?? []).map(override).filter(\.setsPrice)
        return CatalogModel.Pricing(
            prompt: prompt,
            completion: completion,
            cacheRead: price(pricing.inputCacheRead),
            cacheWrite: price(pricing.inputCacheWrite),
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
            cacheWrite: price(override.inputCacheWrite)
        )
    }

    private static func price(_ text: String?) -> String? {
        text.flatMap { $0.hasPrefix("-") ? nil : $0 }
    }
}
