extension OpenAIModelList {
    /// The parameters every model takes.
    private static let commonParameters = ["max_output_tokens"]

    /// The parameters a model that calls tools takes.
    private static let toolParameters = ["parallel_tool_calls", "tool_choice", "tools"]

    /// The parameter of a model whose answers the host holds to a schema.
    private static let structuredOutputsParameter = "structured_outputs"

    /// The parameters of a model that takes sampling settings.
    private static let samplingParameters = ["temperature", "top_p"]

    /// The parameter of a model that reasons.
    private static let reasoningParameter = "reasoning"

    /// The models in catalog form: each model OpenAI serves that the Responses API takes and that generates text, with
    /// what models.dev says it takes and does.
    ///
    /// A model whose shutdown day has passed is left out, although OpenAI may still list it. A dated snapshot, such as
    /// `gpt-5-2025-08-07`, takes what its model, `gpt-5`, takes, and its model's name with its day, when models.dev
    /// doesn't list it. A model models.dev doesn't describe, such as one that only works with a tool of its own, is left out, since
    /// the catalog can't say what it takes. A model that reasons and takes `none` reasons unless a request turns it off,
    /// since OpenAI's default effort is the description's; one that doesn't take `none` always reasons.
    ///
    /// - Parameters:
    ///   - descriptions: What models.dev says about OpenAI's models.
    ///   - responsesModelIDs: The ids of the models that take the Responses API.
    ///   - everyEffort: Every effort word, highest first, which orders each model's efforts.
    ///   - defaultEffort: The effort a model uses when a request doesn't set one.
    ///   - today: The day of the fetch, in UTC.
    /// - Returns: The models, sorted by id.
    func catalogModels(
        describedBy descriptions: ModelsDevCatalog,
        responsesModelIDs: Set<String>,
        everyEffort: [String],
        defaultEffort: String?,
        today: CatalogDay
    ) -> [CatalogModel] {
        data.filter { responsesModelIDs.contains($0.id) }.sorted { $0.id < $1.id }.compactMap { model in
            let shutdown = model.shutdownDate.flatMap(CatalogDay.init)
            if let shutdown, shutdown.start < today.start { return nil }
            // A dated snapshot that models.dev doesn't list takes its model's description and name, with its day.
            let undated = descriptions.models[model.id] == nil ? Self.undated(model.id) : nil
            guard let description = descriptions.models[model.id] ?? undated.flatMap({ descriptions.models[$0.id] }),
                description.type == nil, description.modalities.output == [CatalogModel.textModality]
            else { return nil }
            let reasons = description.reasoning == true
            let efforts = reasons ? Self.highestFirst(description.efforts, ranking: everyEffort) : []
            var parameters = Self.commonParameters
            if description.toolCall == true { parameters += Self.toolParameters }
            if description.structuredOutput == true { parameters.append(Self.structuredOutputsParameter) }
            if description.temperature == true { parameters += Self.samplingParameters }
            if reasons { parameters.append(Self.reasoningParameter) }
            let displayName = undated.map { "\(description.name) (\($0.day))" } ?? description.name
            return CatalogModel(
                id: model.id,
                displayName: displayName,
                aliasTarget: nil,
                releasedAt: model.created,
                knowledgeCutoff: description.knowledge.flatMap(Self.day(of:)),
                expirationDate: shutdown,
                contextSize: description.limit?.context,
                inputModalities: Set(description.modalities.input).sorted(),
                outputModalities: [CatalogModel.textModality],
                supportedParameters: parameters.sorted(),
                reasoningEfforts: efforts,
                defaultReasoningEffort: defaultEffort.flatMap { efforts.contains($0) ? $0 : nil },
                reasoning: Self.reasoning(reasons: reasons, efforts: efforts),
                cachesOnlyMarkedPrompts: false
            )
        }
    }

    /// A model's efforts, highest first: those the ranking knows in its order, then any other, highest first, as
    /// models.dev lists efforts lowest first.
    private static func highestFirst(_ efforts: [String], ranking: [String]) -> [String] {
        ranking.filter(efforts.contains) + efforts.filter { !ranking.contains($0) }.reversed()
    }

    /// Whether and when a model reasons: never, unless a request turns it off when it takes `none`, or always.
    private static func reasoning(reasons: Bool, efforts: [String]) -> CatalogReasoning {
        guard reasons else { return .unsupported }
        return efforts.contains(EffortRanking.offWord) ? .optional(enabledByDefault: true) : .mandatory
    }

    /// The model a dated snapshot's id names, and the snapshot's day, such as `gpt-5` and `2025-08-07` for
    /// `gpt-5-2025-08-07`, or `nil` for an id without a date.
    private static func undated(_ id: String) -> (id: String, day: String)? {
        guard let match = id.wholeMatch(of: /(.+)-(\d{4}-\d{2}-\d{2})/) else { return nil }
        return (String(match.1), String(match.2))
    }

    /// The day training data ends: the day itself, or the first day of a month written as `yyyy-MM`.
    private static func day(of knowledge: String) -> CatalogDay? {
        CatalogDay(knowledge) ?? CatalogDay("\(knowledge)-01")
    }
}
