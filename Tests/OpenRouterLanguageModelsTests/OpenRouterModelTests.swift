import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTesting
import Testing

@testable import OpenRouterLanguageModels

@Suite("OpenRouter model")
struct OpenRouterModelTests {
    @Test func `capabilities come from the parameters, inputs and reasoning the model has`() {
        let model = model(parameters: [.tools, .responseFormat], inputs: [.text, .image], reasoning: .mandatory)

        #expect(model.capabilities.listed == [.toolCalling, .guidedGeneration, .reasoning, .vision])
    }

    @Test func `a text-only model without tools, schemas or reasoning has no capabilities`() {
        #expect(model(parameters: [.temperature], inputs: [.text], reasoning: .unsupported).capabilities.listed.isEmpty)
    }

    @Test func `a typed model turns into its open form`() {
        let typed = model(parameters: [.reasoning], inputs: [.text], reasoning: .optional(enabledByDefault: true))

        let open = OpenRouterModel<ContextOptions.ReasoningLevel>(typed)

        #expect(open.id == typed.id)
        #expect(open.reasoning == typed.reasoning)
        #expect(open.reasoningEfforts == [.max, .low, .off])
        #expect(open.defaultReasoningEffort == .low)
        #expect(open.knowledgeCutoff == typed.knowledgeCutoff)
        #expect(open.pricing == typed.pricing)
    }

    @Test func `the catalog lookup gives nil for an unknown id`() {
        #expect(OpenRouterModel(catalogID: "vendor/not-a-model") == nil)
    }

    @Test func `a model id encodes as its raw value`() throws {
        let id: OpenRouterModelID = "typesafe/jev-router"
        let data = try JSONEncoder().encode(id)

        #expect(String(decoding: data, as: UTF8.self) == #""typesafe\/jev-router""#)
        #expect(try JSONDecoder().decode(OpenRouterModelID.self, from: data) == id)
    }

    private func model(
        parameters: Set<OpenRouterParameter>,
        inputs: Set<OpenRouterModality>,
        reasoning: OpenRouterReasoning
    ) -> OpenRouterModel<Efforts.MaxHighLowOff> {
        OpenRouterModel(
            id: "vendor/model",
            displayName: "Vendor: Model",
            releaseDate: Date(timeIntervalSince1970: 1_793_000_000),
            knowledgeCutoff: Date(timeIntervalSince1970: 1_782_777_600),
            expirationDate: nil,
            contextSize: 200_000,
            maximumResponseTokens: 8_192,
            inputModalities: inputs,
            outputModalities: [.text],
            supportedParameters: parameters,
            reasoning: reasoning,
            reasoningEfforts: [.max, .low, .off],
            defaultReasoningEffort: .low,
            pricing: OpenRouterPricing(
                prompt: Decimal(sign: .plus, exponent: -6, significand: 3),
                completion: Decimal(sign: .plus, exponent: -6, significand: 15),
                cacheRead: Decimal(sign: .plus, exponent: -7, significand: 3),
                cacheWrite: nil
            )
        )
    }
}
