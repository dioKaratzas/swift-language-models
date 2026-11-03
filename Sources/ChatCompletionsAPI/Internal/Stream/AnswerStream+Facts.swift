import FoundationModels
import LanguageModels

extension AnswerStream {
    /// What an answer's chunks report about it in the format's own members: the model that answered, the response id,
    /// the service tier, the usage and why the answer ended.
    ///
    /// Chunks repeat some facts and leave out others, so a fact that a chunk reports replaces the earlier one, and one
    /// it leaves out keeps its earlier value.
    struct Facts {
        /// The model that answered, as the answer names it.
        private(set) var model: String?

        /// The answer's id.
        private(set) var responseID: String?

        /// The processing tier that served the answer, in the host's word for it.
        private(set) var serviceTier: String?

        /// The usage as Foundation Models' running totals.
        private(set) var usage: AnswerStream.Facts.Usage?

        private(set) var finishReason: FinishReason?

        /// Takes the facts that a chunk reports.
        mutating func update(with chunk: ChatCompletionChunk) {
            responseID = chunk.id ?? responseID
            model = chunk.model ?? model
            serviceTier = chunk.serviceTier ?? serviceTier
            if let usage = chunk.usage {
                self.usage = AnswerStream.Facts.Usage(usage)
            }
            finishReason = chunk.choices?.first?.finishReason ?? finishReason
        }

        /// The facts as metadata of the entry that ends the answer; the usage goes with the entry's usage instead.
        var metadata: [String: any ConvertibleToGeneratedContent] {
            var metadata: [String: any ConvertibleToGeneratedContent] = [:]
            metadata[LanguageModelMetadataKey.model] = model
            metadata[LanguageModelMetadataKey.responseID] = responseID
            metadata[LanguageModelMetadataKey.finishReason] = finishReason?.rawValue
            metadata[LanguageModelMetadataKey.serviceTier] = serviceTier
            return metadata
        }
    }
}

extension AnswerStream.Facts {
    /// The usage a chunk reported, as Foundation Models' running totals, with the prompt tokens written to the host's
    /// cache in the metadata.
    struct Usage {
        let input: LanguageModelExecutorGenerationChannel.Usage.Input
        let output: LanguageModelExecutorGenerationChannel.Usage.Output
        let metadata: [String: any ConvertibleToGeneratedContent]

        init(_ usage: ChatCompletionChunk.Usage) {
            input = .init(totalTokenCount: usage.promptTokens ?? 0, cachedTokenCount: usage.promptTokensDetails?.cachedTokens ?? 0)
            output = .init(
                totalTokenCount: usage.completionTokens ?? 0,
                reasoningTokenCount: usage.completionTokensDetails?.reasoningTokens ?? 0
            )
            var metadata: [String: any ConvertibleToGeneratedContent] = [:]
            metadata[LanguageModelMetadataKey.cacheWriteTokenCount] = usage.promptTokensDetails?.cacheWriteTokens
            self.metadata = metadata
        }
    }
}
