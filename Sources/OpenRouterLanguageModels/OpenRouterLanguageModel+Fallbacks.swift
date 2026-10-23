public import FoundationModels
import LanguageModels
public import UniformTypeIdentifiers

extension OpenRouterLanguageModel {
    /// What every model a request may reach supports: the model's capabilities, narrowed by its fallbacks'.
    ///
    /// Tool calling, guided generation, reasoning and vision are listed only when the model and each fallback support
    /// them, so whichever model answers can handle the request.
    public var capabilities: LanguageModelCapabilities {
        sharedDetails.capabilities
    }

    /// The model's details, narrowed to what each fallback also supports, for building a request that any of them can
    /// answer. The id, name and prices stay the model's own.
    var sharedDetails: OpenRouterModel<ContextOptions.ReasoningLevel> {
        fallbacks.reduce(OpenRouterModel<ContextOptions.ReasoningLevel>(details)) { $0.sharing($1) }
    }

    /// The ids of the model and its fallbacks, in the order OpenRouter tries them.
    var modelIDs: [OpenRouterModelID] {
        [details.id] + fallbacks.map(\.id)
    }

    /// The input kinds that every model a request may reach takes as attachments, with the model's PDF engine.
    var attachmentInputs: Set<OpenRouterInputModality> {
        sharedDetails.attachmentInputs(pdfEngine: options.pdfEngine)
    }

    /// Whether reasoning goes back in a request, since each request tries the model first and reasoning suits only
    /// the model that wrote it.
    ///
    /// - Parameter writer: The model that wrote the reasoning, as its answer named it, or `nil` when that isn't known.
    /// - Returns: `false` when a fallback, rather than the model, wrote the reasoning; otherwise `true`, also for a
    ///   writer that none of them names, such as the model a router picked.
    func replaysReasoning(writtenBy writer: String?) -> Bool {
        guard let writer else { return true }
        let model = details.specificity(naming: writer) ?? 0
        return fallbacks.allSatisfy { ($0.specificity(naming: writer) ?? 0) <= model }
    }
}

@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
extension OpenRouterLanguageModel {
    /// Whether the model and each of its fallbacks accept the kind of data as a prompt attachment.
    ///
    /// A PDF is accepted by every model, since OpenRouter reads it for a model that can't, unless
    /// ``OpenRouterOptions/pdfEngine`` is ``OpenRouterPDFEngine/native``.
    ///
    /// - Parameter type: The kind of data, such as `UTType.png`.
    /// - Returns: Whether the kind conforms to an attachment kind that every model of the request accepts.
    /// - Throws: Nothing; the method throws only because Foundation Models declares it so.
    public func supportsDataAttachmentType(_ type: UTType) async throws -> Bool {
        OpenRouterInputModality(carrying: type).map(attachmentInputs.contains) ?? false
    }

    /// Whether the model and each of its fallbacks generate the kind of data.
    ///
    /// - Parameter type: The kind of data, such as `UTType.png`.
    /// - Returns: Whether the kind conforms to a data kind that every model of the request generates.
    /// - Throws: Nothing; the method throws only because Foundation Models declares it so.
    public func supportsDataEntryType(_ type: UTType) async throws -> Bool {
        sharedDetails.supportsDataEntryType(type)
    }
}

extension OpenRouterModel where Effort == ContextOptions.ReasoningLevel {
    /// The details narrowed to what another model also supports: the parameters, input and output kinds and efforts
    /// both take, the smaller limits, and reasoning only when both reason. The id, name, dates and prices stay these.
    fileprivate func sharing(_ other: Self) -> Self {
        Self(
            id: id,
            displayName: displayName,
            releaseDate: releaseDate,
            aliasTarget: aliasTarget,
            knowledgeCutoff: knowledgeCutoff,
            expirationDate: expirationDate,
            contextSize: smaller(contextSize, other.contextSize),
            maximumOutputTokens: smaller(maximumOutputTokens, other.maximumOutputTokens),
            inputModalities: inputModalities.intersection(other.inputModalities),
            outputModalities: outputModalities.intersection(other.outputModalities),
            supportedParameters: supportedParameters.intersection(other.supportedParameters),
            reasoning: reasoning.sharing(other.reasoning),
            reasoningEfforts: reasoningEfforts.filter { other.reasoningEfforts.contains($0) },
            defaultReasoningEffort: defaultReasoningEffort == other.defaultReasoningEffort ? defaultReasoningEffort : nil,
            pricing: pricing
        )
    }
}

extension OpenRouterModel {
    /// How specifically an answer's `model` names this model: the length of the id it matches, or `nil` when it
    /// names another model.
    ///
    /// An answer names a model by its id, or by the id an alias points to, without a variant suffix such as `:free`,
    /// and often with a dated version after it, such as `openai/gpt-4.1-nano-2025-04-14`. A longer match is the more
    /// specific one, so `vendor/model-mini-2026-10-01` names `vendor/model-mini` rather than `vendor/model`.
    fileprivate func specificity(naming answerModel: String) -> Int? {
        let named = answerModel.prefix { $0 != ":" }
        return [id, aliasTarget].compactMap { id in
            guard let slug = id?.rawValue.prefix(while: { $0 != ":" }), named == slug || named.hasPrefix(slug + "-") else {
                return nil
            }
            return slug.count
        }.max()
    }
}

extension OpenRouterReasoning {
    /// The reasoning two models share: none when either doesn't reason, always when either always reasons, and by
    /// default only when both reason by default.
    fileprivate func sharing(_ other: Self) -> Self {
        switch (self, other) {
        case (.unsupported, _), (_, .unsupported): .unsupported
        case (.mandatory, _), (_, .mandatory): .mandatory
        case (.optional(let enabled), .optional(let otherEnabled)): .optional(enabledByDefault: enabled && otherEnabled)
        }
    }
}

/// The smaller of two limits, or the one that's known.
private func smaller(_ limit: Int?, _ other: Int?) -> Int? {
    [limit, other].compactMap(\.self).min()
}
