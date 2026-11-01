import Foundation
import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

/// A model that answers every request with the same text.
struct FixedAnswerModel: DetailedLanguageModel {
    struct Details: ModelDetails {
        let id = "fixed"
        let displayName = "Fixed"
        let capabilities = LanguageModelCapabilities([.guidedGeneration])
        let contextSize: Int? = 1_000
        let maximumOutputTokens: Int? = 100
        let reasoningEfforts: [Efforts.Unsupported] = []
        let defaultReasoningEffort: Efforts.Unsupported? = nil
        let removalDate: Date? = nil
        let dataAttachmentTypes: Set<UTType> = []
        let dataEntryTypes: Set<UTType> = []
    }

    struct RequestExecutor: DetailedLanguageModelRequestExecutor {
        struct Configuration: Hashable, Sendable {
            let answer: String
        }

        let configuration: Configuration

        func execute(
            _ request: LanguageModelExecutorGenerationRequest,
            model: FixedAnswerModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws -> DetailedLanguageModelAnswer {
            await channel.send(.response(action: .appendText(configuration.answer, tokenCount: 1)))
            return DetailedLanguageModelAnswer(responseText: configuration.answer)
        }
    }

    let answer: String
    let details = Details()
    let fallbacks: [Details] = []

    var executorConfiguration: RequestExecutor.Configuration { .init(answer: answer) }
}
