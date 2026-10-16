extension OpenRouterModelsResponse {
    /// The models in catalog form.
    ///
    /// A negative price, which OpenRouter uses for models priced per request, becomes no price. A model whose reasoning
    /// is mandatory reasons by default.
    var catalogModels: [CatalogModel] {
        data.map { model in
            let isReasoningMandatory = model.reasoning?.mandatory ?? false
            return CatalogModel(
                id: model.id,
                displayName: model.name,
                releasedAt: model.created,
                knowledgeCutoff: model.knowledgeCutoff,
                expirationDate: model.expirationDate,
                contextSize: model.contextLength,
                maximumResponseTokens: model.topProvider?.maxCompletionTokens,
                inputModalities: model.architecture.inputModalities.sorted(),
                outputModalities: model.architecture.outputModalities.sorted(),
                supportedParameters: (model.supportedParameters ?? []).sorted(),
                reasoningEfforts: model.reasoning?.supportedEfforts ?? [],
                defaultReasoningEffort: model.reasoning?.defaultEffort,
                isReasoningMandatory: isReasoningMandatory,
                reasonsByDefault: isReasoningMandatory || model.reasoning?.defaultEnabled == true,
                pricing: model.pricing.flatMap(Self.pricing)
            )
        }
    }

    private static func pricing(_ pricing: Model.Pricing) -> CatalogModel.Pricing? {
        let price = { (text: String?) in text.flatMap { $0.hasPrefix("-") ? nil : $0 } }
        guard let prompt = price(pricing.prompt), let completion = price(pricing.completion) else { return nil }
        return CatalogModel.Pricing(
            prompt: prompt,
            completion: completion,
            cacheRead: price(pricing.inputCacheRead),
            cacheWrite: price(pricing.inputCacheWrite)
        )
    }
}
