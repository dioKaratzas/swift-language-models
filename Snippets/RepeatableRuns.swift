// snippet.hide
import Evaluations
import Foundation
import FoundationModels
import OpenRouterLanguageModels
import Testing

func sampling() {
    // snippet.show
    // snippet.parameters
    let sampling: [OpenRouterParameter] = [.temperature, .topK, .seed]
    let haiku = OpenRouterModel.anthropicClaudeHaiku5_5.supportedParameters
    print(sampling.filter { !haiku.contains($0) }.map(\.rawValue))  // ["temperature", "top_k", "seed"]

    let deepSeek = OpenRouterModel.deepseekDeepseekV4Flash.supportedParameters
    print(sampling.filter { !deepSeek.contains($0) }.map(\.rawValue))  // []
    // snippet.end
    // snippet.hide
}

// snippet.show
// snippet.pinned
/// The key for live runs. Tests without it skip themselves.
let openRouterKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]

/// One model on one host, with no fallbacks and no response cache.
let modelUnderTest = OpenRouterLanguageModel(
    .deepseekDeepseekV4Flash,  // A catalog model, not an alias such as `~deepseek/deepseek-v4-flash-latest`
    routing: OpenRouterRouting(order: ["deepinfra"], allowsFallbacks: false, requiresParameters: true),
    options: OpenRouterOptions(includesRouterMetadata: true),  // Reports how long the host took
    responseCache: nil,
    apiKey: { openRouterKey ?? "" }
)
// snippet.end

// snippet.answer
/// An answer, with the model and host that served it, what it cost and how long the host took.
struct Answer: Codable, Sendable {
    var text: String
    var model: String?
    var provider: String?
    var dollars: Double?
    var seconds: Double?
}

struct ShortRecipeEvaluation: Evaluation {
    static let short = Metric("Short")
    static let cost = Metric("Cost")
    static let hostTime = Metric("HostTime")

    let model: any LanguageModel

    var dataset: ArrayLoader<ModelSample<Answer>> {
        let prompts = ["Something with lentils.", "A quick vegan breakfast."]
        return ArrayLoader(samples: prompts.map { ModelSample(prompt: $0, expected: nil) })
    }

    func subject(from sample: ModelSample<Answer>) async throws -> ModelSubject<Answer> {
        let session = LanguageModelSession(model: model, instructions: "Suggest one recipe in under 150 words.")
        let response = try await session.respond(to: sample.prompt, options: GenerationOptions(samplingMode: .greedy))
        var answer = Answer(text: response.content)
        if case .response(let entry)? = response.transcriptEntries.last {
            answer.model = entry.openRouter.model?.rawValue
            answer.provider = entry.openRouter.provider
            answer.seconds = entry.openRouter.generationTime.map { $0 / .seconds(1) }
        }
        answer.dollars = response.usage.openRouter.cost.map { NSDecimalNumber(decimal: $0).doubleValue }
        return ModelSubject(value: answer)
    }

    var evaluators: Evaluators {
        Evaluator { _, subject in
            subject.value.text.split(separator: " ").count < 150 ? Self.short.passing() : Self.short.failing()
        }
        Evaluator { _, subject in subject.value.dollars.map { Self.cost.scoring($0) } ?? Self.cost.ignore() }
        Evaluator { _, subject in subject.value.seconds.map { Self.hostTime.scoring($0) } ?? Self.hostTime.ignore() }
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: Self.short)
        aggregator.computeMean(of: Self.cost)
        aggregator.computeStandardDeviation(of: Self.cost)
        aggregator.computeMean(of: Self.hostTime)
        aggregator.computeStandardDeviation(of: Self.hostTime)
    }
}
// snippet.end

// snippet.variance
@Test(.enabled(if: openRouterKey != nil, "Set OPENROUTER_API_KEY to run this test"))
func recipesStayShortAcrossRuns() async throws {
    let evaluation = ShortRecipeEvaluation(model: modelUnderTest)
    var passRates: [Double] = []
    for run in 1...5 {
        let result = try await evaluation.run(info: ["model": modelUnderTest.details.id.rawValue, "run": "\(run)"])
        // A sample whose request failed is left out of the scores, so a run with failures measured less.
        #expect(result.errors.inferenceFailureCount == 0)
        passRates.append(result.aggregateValue(.mean(of: ShortRecipeEvaluation.short)))
    }
    // The answers differ from run to run, so the test bounds the worst run and the spread, not the text.
    let worst = passRates.min() ?? 0
    #expect(worst >= 0.9)
    #expect((passRates.max() ?? 0) - worst <= 0.1)
}
// snippet.end
