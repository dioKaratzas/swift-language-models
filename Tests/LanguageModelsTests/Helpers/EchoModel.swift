import Foundation
import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

/// A model that answers every request with the reasoning level it received.
struct EchoModel<Effort: ModelEffort>: DetailedLanguageModel {
    struct Details: ModelDetails {
        var id = "echo"
        let displayName = "Echo"
        let capabilities = LanguageModelCapabilities([.toolCalling, .reasoning])
        let contextSize: Int? = 1_000
        let maximumOutputTokens: Int? = 100
        let reasoningEfforts: [Effort]
        var defaultReasoningEffort: Effort? { reasoningEfforts.first }
        var removalDate: Date?
        let dataAttachmentTypes: Set<UTType> = [.image]
        let dataEntryTypes: Set<UTType> = []
    }

    struct RequestExecutor: DetailedLanguageModelRequestExecutor {
        struct Configuration: Hashable, Sendable {}

        init(configuration: Configuration) {}

        func execute(
            _ request: LanguageModelExecutorGenerationRequest,
            model: EchoModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws -> DetailedLanguageModelAnswer {
            let level =
                switch request.contextOptions.reasoningLevel {
                case .custom(let value)?: value
                case .light?: "light"
                case .moderate?: "moderate"
                case .deep?: "deep"
                case nil: "default"
                @unknown default: "unknown"
                }
            await channel.send(.response(action: .appendText(level, tokenCount: 1)))
            return DetailedLanguageModelAnswer(responseText: level)
        }
    }

    let details: Details
    let fallbacks: [Details]

    var executorConfiguration: RequestExecutor.Configuration { .init() }

    init(efforts: [Effort], removalDate: Date? = nil, fallbacks: [Details] = []) {
        details = Details(reasoningEfforts: efforts, removalDate: removalDate)
        self.fallbacks = fallbacks
    }
}

/// The efforts of a model that accepts only `high` and `low`.
enum HighLowEffort: String, ModelEffort {
    case high
    case low
}
