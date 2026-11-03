extension OpenAIModelList {
    /// The parameters every model takes.
    private static let commonParameters = ["max_output_tokens"]

    /// The parameters a model that calls tools takes.
    private static let toolParameters = ["parallel_tool_calls", "tool_choice", "tools"]

    /// The parameter of a model whose answers the host holds to a schema.
    private static let structuredOutputsParameter = "structured_outputs"

    /// The parameters of a model that takes sampling settings.
    private static let samplingParameters = ["temperature", "top_p"]

    /// Every parameter a model can take.
    static var everyParameter: Set<String> {
        Set(commonParameters + toolParameters + [structuredOutputsParameter] + samplingParameters + [CatalogModel.reasoningParameter])
    }

    /// What models.dev says about a served model.
    private enum Description {
        /// The model's entry, or its model's for a dated snapshot that models.dev doesn't list, with the snapshot's
        /// day.
        case entry(ModelsDevCatalog.Model, day: String?)
        /// The entry that would describe the model doesn't decode.
        case undecoded
        /// models.dev doesn't list the model.
        case missing
    }

    /// The models in catalog form: each model OpenAI serves that models.dev describes as a model that generates text,
    /// with what models.dev says it takes and does.
    ///
    /// The API description's lists of model ids don't decide which models the catalog lists: OpenAI serves models for
    /// the Responses API that they leave out, and may drop the id of a model it still serves. A model that works only
    /// with Chat Completions or another endpoint is left out by its id instead, as ``worksOnlyWithOtherEndpoints(_:)``
    /// tells.
    ///
    /// A model whose shutdown day has passed is left out, although OpenAI may still list it. A dated snapshot, such as
    /// `gpt-5-2025-08-07`, takes what its model, `gpt-5`, takes, and its model's name with its day, when models.dev
    /// doesn't list it. A model models.dev doesn't describe, such as one that only works with a tool of its own, is
    /// left out, since the catalog can't say what it takes, and so is one whose entry doesn't decode, which
    /// ``undescribedModelIDs(describedBy:today:)`` lists.
    ///
    /// A model that reasons and takes `none` is recorded as reasoning unless a request turns it off, which assumes its
    /// default effort isn't `none`; one that doesn't take `none` always reasons. Neither models.dev nor the API
    /// description gives a model's own default effort, so each model that takes the description's default, which it
    /// gives for every model, records it as its default, although the model's own may differ.
    ///
    /// - Parameters:
    ///   - descriptions: What models.dev says about OpenAI's models.
    ///   - everyEffort: Every effort word, highest first, which orders each model's efforts.
    ///   - defaultEffort: The default effort the API description gives for every model, which may not be a model's own.
    ///   - today: The day of the fetch, in UTC.
    /// - Returns: The models, sorted by id.
    func catalogModels(
        describedBy descriptions: ModelsDevCatalog,
        everyEffort: [String],
        defaultEffort: String?,
        today: CatalogDay
    ) -> [CatalogModel] {
        candidates(today: today).compactMap { model in
            guard case .entry(let description, let day) = Self.description(of: model.id, in: descriptions),
                description.type == nil, description.modalities.output == [CatalogModel.textModality]
            else { return nil }
            let reasons = description.reasoning == true
            let efforts = reasons ? Self.highestFirst(description.efforts, ranking: everyEffort) : []
            var parameters = Self.commonParameters
            if description.toolCall == true { parameters += Self.toolParameters }
            if description.structuredOutput == true { parameters.append(Self.structuredOutputsParameter) }
            if description.temperature == true { parameters += Self.samplingParameters }
            if reasons { parameters.append(CatalogModel.reasoningParameter) }
            let displayName = day.map { "\(description.name) (\($0))" } ?? description.name
            return CatalogModel(
                id: model.id,
                displayName: displayName,
                aliasTarget: nil,
                releasedAt: model.created,
                knowledgeCutoff: description.knowledge.flatMap(Self.day(of:)),
                expirationDate: model.shutdownDate,
                contextSize: description.limit?.context,
                inputModalities: Set(description.modalities.input).sorted(),
                outputModalities: [CatalogModel.textModality],
                supportedParameters: parameters.sorted(),
                reasoningEfforts: efforts,
                // The description's default for every model, not one OpenAI gives for this model.
                defaultReasoningEffort: defaultEffort.flatMap { efforts.contains($0) ? $0 : nil },
                reasoning: Self.reasoning(reasons: reasons, efforts: efforts),
                cachesOnlyMarkedPrompts: false
            )
        }
    }

    /// The ids of the models the catalog could list but leaves out because the models.dev entries that would describe
    /// them don't decode, so it can't tell whether they generate text, or what they take.
    ///
    /// - Parameters:
    ///   - descriptions: What models.dev says about OpenAI's models.
    ///   - today: The day of the fetch, in UTC.
    /// - Returns: The ids.
    func undescribedModelIDs(describedBy descriptions: ModelsDevCatalog, today: CatalogDay) -> Set<String> {
        Set(
            candidates(today: today).map(\.id).filter { id in
                if case .undecoded = Self.description(of: id, in: descriptions) { true } else { false }
            }
        )
    }

    /// Whether a model works only with Chat Completions or with an endpoint other than the Responses API, which a word
    /// of its id tells, as OpenAI's model pages list each model's endpoints:
    /// - `audio` and `search`: Chat Completions only, as `gpt-audio-mini` and `gpt-4o-search-preview`, since the
    ///   Responses API searches with a tool instead;
    /// - `instruct`: the legacy Completions endpoint only, as `gpt-3.5-turbo-instruct`;
    /// - `realtime`, `transcribe` and `tts`: the Realtime, transcription and speech endpoints, as `gpt-realtime`,
    ///   `gpt-4o-mini-transcribe` and `gpt-4o-mini-tts`.
    ///
    /// Only the id tells them apart, since models.dev may describe one as a model that generates text, and the API
    /// description's Chat Completions list names some of them.
    static func worksOnlyWithOtherEndpoints(_ id: String) -> Bool {
        id.contains(/(?:^|-)(?:audio|instruct|realtime|search|transcribe|tts)(?:-|$)/)
    }

    /// The served models the catalog could list, sorted by id: those whose shutdown day hasn't passed, other than
    /// those that work only with another endpoint.
    private func candidates(today: CatalogDay) -> [Model] {
        data.filter { model in
            !Self.worksOnlyWithOtherEndpoints(model.id) && model.shutdownDate.map { $0.start >= today.start } ?? true
        }.sorted { $0.id < $1.id }
    }

    /// What models.dev says about a served model: its own entry, or for a dated snapshot without one, its model's.
    private static func description(of id: String, in descriptions: ModelsDevCatalog) -> Description {
        if let model = descriptions.models[id] { return .entry(model, day: nil) }
        if descriptions.undecodedIDs.contains(id) { return .undecoded }
        guard let undated = undated(id) else { return .missing }
        if let model = descriptions.models[undated.id] { return .entry(model, day: undated.day) }
        return descriptions.undecodedIDs.contains(undated.id) ? .undecoded : .missing
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
