extension OpenRouterModelsResponse {
    /// The models in catalog form.
    ///
    /// A negative price, which OpenRouter uses for models priced per request, becomes no price.
    var catalogModels: [CatalogModel] {
        data.map { model in
            CatalogModel(
                id: model.id,
                displayName: model.name,
                contextSize: model.contextLength,
                maximumResponseTokens: model.topProvider?.maxCompletionTokens,
                inputModalities: model.architecture.inputModalities.sorted(),
                supportedParameters: (model.supportedParameters ?? []).sorted(),
                reasoningEfforts: model.reasoning?.supportedEfforts ?? [],
                defaultReasoningEffort: model.reasoning?.defaultEffort,
                pricing: model.pricing.flatMap { pricing in
                    guard !pricing.prompt.hasPrefix("-"), !pricing.completion.hasPrefix("-") else { return nil }
                    return CatalogModel.Pricing(prompt: pricing.prompt, completion: pricing.completion)
                }
            )
        }
    }
}
