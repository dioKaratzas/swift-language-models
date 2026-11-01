// snippet.hide
import Evaluations
import Foundation
import FoundationModels
import Synchronization
import Testing

// snippet.show
// snippet.model
/// A model that answers from a script, so tests run offline and get the same answer every time.
struct ScriptedModel: LanguageModel {
    /// What the model does on one turn of an answer.
    enum Turn: Sendable {
        /// Answers with text, which is JSON for a guided-generation request.
        case text(String)

        /// Calls a tool with arguments written as JSON. The session runs the tool and asks the model again.
        case toolCall(name: String, arguments: String)

        /// Throws an error, as a provider does when a request fails.
        case failure(any Error)
    }

    /// The turns the model takes for each prompt, in order. The last one repeats.
    let turns: [Turn]

    /// What the model tells Foundation Models it can do.
    let capabilities: LanguageModelCapabilities

    /// The token counts each turn reports.
    let usage: LanguageModelExecutorGenerationChannel.Usage

    /// Every request the model received, in order.
    let requests = RequestLog()

    init(
        _ turns: Turn...,
        capabilities: [LanguageModelCapabilities.Capability] = [.guidedGeneration, .toolCalling],
        usage: LanguageModelExecutorGenerationChannel.Usage = .init(
            input: .init(totalTokenCount: 120, cachedTokenCount: 0),
            output: .init(totalTokenCount: 30, reasoningTokenCount: 0)
        )
    ) {
        precondition(!turns.isEmpty, "A script needs at least one turn.")
        self.turns = turns
        self.capabilities = LanguageModelCapabilities(capabilities)
        self.usage = usage
    }

    var executorConfiguration: Executor.Configuration { Executor.Configuration() }
}

/// The requests a scripted model received.
final class RequestLog: Sendable {
    private let requests = Mutex<[LanguageModelExecutorGenerationRequest]>([])

    /// Every request so far, in order.
    var all: [LanguageModelExecutorGenerationRequest] { requests.withLock { $0 } }

    func append(_ request: LanguageModelExecutorGenerationRequest) {
        requests.withLock { $0.append(request) }
    }
}
// snippet.end

// snippet.executor
extension ScriptedModel {
    struct Executor: LanguageModelExecutor {
        struct Configuration: Hashable, Sendable {}

        init(configuration: Configuration) {}

        func respond(
            to request: LanguageModelExecutorGenerationRequest,
            model: ScriptedModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
            model.requests.append(request)
            let (index, turn) = model.turn(for: request.transcript)
            let usage = model.usage
            switch turn {
            case .text(let text):
                await channel.send(.response(action: .appendText(text, tokenCount: usage.output.totalTokenCount)))
                await channel.send(.response(action: .updateUsage(input: usage.input, output: usage.output)))
            case .toolCall(let name, let arguments):
                let call = LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall.Action.appendArguments(
                    arguments,
                    tokenCount: usage.output.totalTokenCount
                )
                await channel.send(.toolCalls(action: .toolCall(id: "call-\(index)", name: name, action: call)))
                await channel.send(.toolCalls(action: .updateUsage(input: usage.input, output: usage.output)))
            case .failure(let error):
                throw error
            }
        }
    }

    /// The turn for a request: one for each tool call and answer since the transcript's last prompt, so every
    /// prompt starts the script again.
    func turn(for transcript: Transcript) -> (index: Int, turn: Turn) {
        var index = 0
        for entry in transcript {
            switch entry {
            case .prompt: index = 0
            case .toolCalls, .response: index += 1
            default: break
            }
        }
        let clamped = min(index, turns.count - 1)
        return (clamped, turns[clamped])
    }
}
// snippet.end

// snippet.feature
@Generable
struct Dinner: Codable, Equatable {
    @Guide(description: "The dish's name.")
    var name: String

    @Guide(description: "The minutes it takes to cook.")
    var minutes: Int
}

/// Finds recipes in the app's own collection.
struct RecipeSearch: Tool {
    let name = "searchRecipes"
    let description = "Finds recipes that use an ingredient."

    @Generable
    struct Arguments {
        @Guide(description: "An ingredient the recipe uses.")
        var ingredient: String
    }

    func call(arguments: Arguments) async throws -> String {
        "Lentil soup with carrots and cumin, 30 minutes."
    }
}

/// Suggests a dinner from the app's recipes.
func suggestDinner(for request: String, using model: some LanguageModel) async throws -> Dinner {
    let session = LanguageModelSession(
        model: model,
        tools: [RecipeSearch()],
        instructions: "Suggest one dinner from the recipes you find."
    )
    return try await session.respond(to: request, generating: Dinner.self).content
}

/// What the app shows for a dinner request.
func dinnerMessage(for request: String, using model: some LanguageModel) async -> String {
    do {
        let dinner = try await suggestDinner(for: request, using: model)
        return "\(dinner.name), ready in \(dinner.minutes) minutes."
    } catch LanguageModelError.rateLimited {
        return "Too many requests. Try again in a minute."
    } catch LanguageModelError.guardrailViolation, LanguageModelError.refusal {
        return "Try asking for a different dinner."
    } catch {
        return "No dinner ideas right now."
    }
}
// snippet.end

// snippet.text
@Test func suggestsTheScriptedDinner() async throws {
    let model = ScriptedModel(.text(#"{"name": "Lentil soup", "minutes": 30}"#))

    let dinner = try await suggestDinner(for: "Something warm.", using: model)

    #expect(dinner == Dinner(name: "Lentil soup", minutes: 30))
}
// snippet.end

// snippet.tools
@Test func searchesBeforeSuggesting() async throws {
    let model = ScriptedModel(
        .toolCall(name: "searchRecipes", arguments: #"{"ingredient": "lentils"}"#),
        .text(#"{"name": "Lentil soup", "minutes": 30}"#)
    )

    let dinner = try await suggestDinner(for: "Something with lentils.", using: model)

    #expect(dinner.name == "Lentil soup")
    #expect(model.requests.all.count == 2)
}
// snippet.end

// snippet.errors
@Test(arguments: [
    (
        LanguageModelError.rateLimited(.init(resetDate: nil, debugDescription: "Too many requests.")),
        "Too many requests. Try again in a minute."
    ),
    (
        LanguageModelError.guardrailViolation(.init(debugDescription: "The prompt was flagged.")),
        "Try asking for a different dinner."
    ),
])
func explainsFailures(error: LanguageModelError, message: String) async {
    let model = ScriptedModel(.failure(error))

    #expect(await dinnerMessage(for: "Something warm.", using: model) == message)
}
// snippet.end

// snippet.capabilities
@Test func needsGuidedGeneration() async throws {
    let model = ScriptedModel(.text("Lentil soup"), capabilities: [.toolCalling])

    let error = await #expect(throws: LanguageModelError.self) {
        try await suggestDinner(for: "Something warm.", using: model)
    }

    guard case .unsupportedCapability(let unsupported)? = error else {
        Issue.record("Expected an unsupported capability, got \(String(describing: error)).")
        return
    }
    #expect(unsupported.capability == .guidedGeneration)
    #expect(model.requests.all.isEmpty)
}
// snippet.end

// snippet.requests
@Test func sendsTheSearchResultsBack() async throws {
    let model = ScriptedModel(
        .toolCall(name: "searchRecipes", arguments: #"{"ingredient": "lentils"}"#),
        .text(#"{"name": "Lentil soup", "minutes": 30}"#)
    )

    _ = try await suggestDinner(for: "Something with lentils.", using: model)

    let first = try #require(model.requests.all.first)
    #expect(first.enabledToolDefinitions.map(\.name) == ["searchRecipes"])
    #expect(first.schema != nil)

    let second = try #require(model.requests.all.last)
    let outputs = second.transcript.compactMap { entry -> Transcript.ToolOutput? in
        guard case .toolOutput(let output) = entry else { return nil }
        return output
    }
    #expect(outputs.map(\.toolName) == ["searchRecipes"])
}
// snippet.end

// snippet.evaluation
struct DinnerEvaluation: Evaluation {
    let model: any LanguageModel
    let judge: any LanguageModel

    let quick = Metric("Quick")
    let warm = Metric("Warm")

    var dataset: ArrayLoader<ModelSample<Dinner>> {
        ArrayLoader(samples: [ModelSample(prompt: "Something warm in under 45 minutes.", expected: nil)])
    }

    func subject(from sample: ModelSample<Dinner>) async throws -> ModelSubject<Dinner> {
        ModelSubject(value: try await suggestDinner(for: sample.promptDescription, using: model))
    }

    var evaluators: Evaluators {
        Evaluator { _, subject in
            subject.value.minutes <= 45
                ? quick.passing()
                : quick.failing(rationale: "Takes \(subject.value.minutes) minutes.")
        }
        ModelJudgeEvaluator(
            "Warm",
            scale: .passFail(passDescription: "A dish served warm.", failDescription: "A cold dish."),
            judge: judge
        )
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: quick)
        aggregator.computeMean(of: warm)
    }
}
// snippet.end

// snippet.judge
@Test func scoresAQuickWarmDinner() async throws {
    let evaluation = DinnerEvaluation(
        model: ScriptedModel(.text(#"{"name": "Lentil soup", "minutes": 30}"#)),
        judge: ScriptedModel(.text(#"{"Warm_value": "1", "Warm_rationale": "Soup is served hot."}"#))
    )

    let result = try await evaluation.run()

    #expect(result.errors == .clean)
    #expect(result.aggregateValue(.mean(of: evaluation.quick)) == 1)
    #expect(result.aggregateValue(.mean(of: evaluation.warm)) == 1)
}
// snippet.end
