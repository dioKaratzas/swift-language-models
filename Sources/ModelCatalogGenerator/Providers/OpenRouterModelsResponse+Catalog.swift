extension OpenRouterModelsResponse {
    /// The variant suffix of models that work only through OpenRouter's Batch API, not chat completions.
    private static let batchSuffix = ":batch"

    /// The models in catalog form.
    ///
    /// A model whose id ends in `:batch` is left out, because it works only through the Batch API. A model that
    /// accepts every effort lists `everyEffort`, and a model that doesn't list its efforts gets none, as its effort
    /// can't be chosen. A model whose reasoning is mandatory can't take `none`, so it never lists it. A default effort
    /// the model doesn't list is dropped.
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
                cachesOnlyMarkedPrompts: Self.cachesOnlyMarkedPrompts(model)
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

    /// Whether a model's hosts cache a prompt only when the request marks it: Anthropic's for Claude, and Alibaba's
    /// for the Qwen models that list a cache write price. A negative price, which OpenRouter uses for a price that
    /// depends on the request, isn't one.
    private static func cachesOnlyMarkedPrompts(_ model: Model) -> Bool {
        let vendor = model.id.drop { $0 == "~" }.prefix { $0 != "/" }
        return vendor == "anthropic" || (vendor == "qwen" && model.pricing?.inputCacheWrite?.hasPrefix("-") == false)
    }
}
