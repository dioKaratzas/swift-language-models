import FoundationModels
import LanguageModels

/// A model that answers every request with the reasoning level it received.
struct EchoModel<Effort: ModelEffort>: DetailedLanguageModel {
    struct Details: ModelDetails {
        let id = "echo"
        let displayName = "Echo"
        let capabilities = LanguageModelCapabilities([.toolCalling, .reasoning])
        let contextSize: Int? = 1_000
        let maximumResponseTokens: Int? = 100
        let reasoningEfforts: [Effort]
        var defaultReasoningEffort: Effort? { reasoningEfforts.first }
    }

    struct Executor: LanguageModelExecutor {
        struct Configuration: Hashable, Sendable {}

        init(configuration: Configuration) {}

        func respond(
            to request: LanguageModelExecutorGenerationRequest,
            model: EchoModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
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
        }
    }

    let details: Details

    var executorConfiguration: Executor.Configuration { .init() }

    init(efforts: [Effort]) {
        details = Details(reasoningEfforts: efforts)
    }
}

/// The efforts of a model that accepts only `high` and `low`.
enum HighLowEffort: String, ModelEffort {
    case high
    case low

    var reasoningLevel: ContextOptions.ReasoningLevel { .custom(rawValue) }
}
