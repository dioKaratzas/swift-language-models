import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Request adjustments")
struct RequestAdjustmentTests {
    @Test func `a request whose models list every setting it asks for changes nothing`() throws {
        let options = GenerationOptions(samplingMode: .random(top: 40, seed: 7), temperature: 0.5, maximumResponseTokens: 100)

        #expect(try adjustments(model(HTTPStub()), options: options).isEmpty)
    }

    @Test func `settings the models don't list are left out, in the order the body has them`() throws {
        let options = GenerationOptions(samplingMode: .random(top: 40, seed: 7), temperature: 0.5, maximumResponseTokens: 100)
        let model = model(
            HTTPStub(), parameters: [.maxTokens, .presencePenalty],
            options: OpenRouterOptions(frequencyPenalty: 0.5, presencePenalty: 0.5, stopSequences: ["END"]))

        #expect(try adjustments(model, options: options) == [.unlistedParameters([.temperature, .topK, .seed, .frequencyPenalty, .stop])])
    }

    @Test func `a token limit is left out when the models list neither of its parameters`() throws {
        let model = model(HTTPStub(), parameters: [.temperature])

        #expect(try adjustments(model, options: GenerationOptions(maximumResponseTokens: 100)) == [.unlistedParameters([.maxTokens])])
    }

    @Test func `greedy sampling is left out only when the models don't list temperature`() throws {
        let greedy = GenerationOptions(samplingMode: .greedy)

        #expect(try adjustments(model(HTTPStub(), parameters: [.temperature]), options: greedy).isEmpty)
        #expect(try adjustments(model(HTTPStub(), parameters: [.topK]), options: greedy) == [.unlistedParameters([.temperature])])
    }

    @Test(arguments: [
        (ContextOptions.ReasoningLevel.moderate, RequestAdjustment?.some(.movedEffort(requested: "medium", sent: "low"))),
        (.deep, nil),
        (.off, .movedEffort(requested: "none", sent: "low")),
        (.custom("turbo"), .movedEffort(requested: "turbo", sent: nil)),
    ])
    func `a reasoning level the models don't accept moves to the nearest effort, or is left out`(
        level: ContextOptions.ReasoningLevel,
        adjustment: RequestAdjustment?
    ) throws {
        let model: OpenRouterLanguageModel<ContextOptions.ReasoningLevel> = model(HTTPStub(), efforts: [.custom("high"), .custom("low")])

        #expect(try adjustments(model, reasoningLevel: level) == [adjustment].compactMap(\.self))
    }

    @Test func `metadata past OpenRouter's limits, or not a string, is left out and named by key`() {
        var metadata: [String: GeneratedContent] = Dictionary(
            uniqueKeysWithValues: (100..<117).map { ("key\($0)", GeneratedContent("value")) })
        metadata["count"] = GeneratedContent(3)
        metadata[String(repeating: "k", count: 65)] = GeneratedContent("too long a key")
        metadata["long"] = GeneratedContent(String(repeating: "v", count: 513))

        let (json, droppedKeys) = ChatCompletionRequest.metadata(metadata)

        #expect(droppedKeys == ["count", String(repeating: "k", count: 65), "key116", "long"].sorted())
        guard case .object(let sent)? = json else {
            Issue.record("The metadata isn't an object: \(String(describing: json))")
            return
        }
        #expect(sent.members.map(\.key) == (100..<116).map { "key\($0)" })
    }

    @Test func `a request with metadata it leaves out notes the keys`() throws {
        let adjustments = try adjustments(model(HTTPStub()), metadata: ["count": 3, "name": "Ada"])

        #expect(adjustments == [.droppedMetadata(keys: ["count"])])
    }

    @Test(arguments: [
        RequestAdjustment.unlistedParameters([.temperature, .seed]),
        .droppedMetadata(keys: ["user-qz9@example.com"]),
        .movedEffort(requested: "medium", sent: "low"),
        .movedEffort(requested: "turbo", sent: nil),
    ])
    func `each message names the model and never a metadata key`(adjustment: RequestAdjustment) {
        let message = adjustment.message(model: "vendor/model")

        #expect(message.contains("vendor/model"))
        #expect(!message.contains("qz9"))
    }

    @Test func `the runtime warning adds the keys of metadata left out to the message`() {
        let dropped = RequestAdjustment.droppedMetadata(keys: ["count", "note"])
        let moved = RequestAdjustment.movedEffort(requested: "medium", sent: "low")

        #expect(dropped.warning(model: "vendor/model") == "\(dropped.message(model: "vendor/model")) Keys: count, note.")
        #expect(moved.warning(model: "vendor/model") == moved.message(model: "vendor/model"))
    }

    @Test func `a time to live outside OpenRouter's range is clamped to whole seconds from 1 second to 24 hours`() {
        #expect(OpenRouterResponseCache.timeToLive(clamping: .milliseconds(1_500)) == .seconds(1))
        #expect(OpenRouterResponseCache.timeToLive(clamping: .zero) == .seconds(1))
        #expect(OpenRouterResponseCache.timeToLive(clamping: .seconds(90_000)) == .seconds(86_400))
        #expect(OpenRouterResponseCache.timeToLive(clamping: .seconds(600)) == .seconds(600))
    }
}

/// The adjustments of the request for one prompt.
private func adjustments(
    _ model: OpenRouterLanguageModel<some ModelEffort>,
    options: GenerationOptions = GenerationOptions(),
    reasoningLevel: ContextOptions.ReasoningLevel? = nil,
    metadata: [String: any ConvertibleToGeneratedContent] = [:]
) throws -> [RequestAdjustment] {
    let request = LanguageModelExecutorGenerationRequest(
        id: UUID(), transcript: Transcript(entries: [.prompt(Transcript.Prompt(segments: [.text(.init(content: "Hi"))]))]),
        enabledTools: [], generationOptions: options, contextOptions: ContextOptions(reasoningLevel: reasoningLevel),
        metadata: metadata)
    return try ChatCompletionRequest(request, model: model, details: model.sharedDetails).adjustments
}
