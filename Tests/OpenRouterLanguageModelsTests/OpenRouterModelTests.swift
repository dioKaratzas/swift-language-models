import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTesting
import Testing

@testable import OpenRouterLanguageModels

@Suite("OpenRouter model")
struct OpenRouterModelTests {
    @Test func `capabilities come from the parameters and inputs the model accepts`() {
        let model = model(parameters: ["tools", "response_format", "reasoning"], inputs: ["text", "image"])

        #expect(model.capabilities.listed == [.toolCalling, .guidedGeneration, .reasoning, .vision])
    }

    @Test func `a text-only model without tools or schemas has no capabilities`() {
        #expect(model(parameters: ["temperature"], inputs: ["text"]).capabilities.listed.isEmpty)
    }

    @Test func `a typed model turns into its open form`() {
        let typed = model(parameters: ["reasoning"], inputs: ["text"])

        let open = OpenRouterModel<ContextOptions.ReasoningLevel>(typed)

        #expect(open.id == typed.id)
        #expect(open.reasoningEfforts == [.max, .low, .off])
        #expect(open.defaultReasoningEffort == .low)
        #expect(open.isReasoningMandatory == typed.isReasoningMandatory)
        #expect(open.knowledgeCutoff == typed.knowledgeCutoff)
        #expect(open.pricing == typed.pricing)
    }

    @Test func `the catalog lookup gives nil for an unknown id`() {
        #expect(OpenRouterModel(catalogID: "vendor/not-a-model") == nil)
    }

    private func model(parameters: Set<String>, inputs: Set<String>) -> OpenRouterModel<Efforts.MaxHighLowOff> {
        OpenRouterModel(
            id: "vendor/model",
            displayName: "Vendor: Model",
            releaseDate: Date(timeIntervalSince1970: 1_793_000_000),
            knowledgeCutoff: Date(timeIntervalSince1970: 1_782_777_600),
            expirationDate: nil,
            contextSize: 200_000,
            maximumResponseTokens: 8_192,
            inputModalities: inputs,
            outputModalities: ["text"],
            supportedParameters: parameters,
            reasoningEfforts: [.max, .low, .off],
            defaultReasoningEffort: .low,
            isReasoningMandatory: true,
            reasonsByDefault: true,
            pricing: OpenRouterPricing(
                prompt: Decimal(sign: .plus, exponent: -6, significand: 3),
                completion: Decimal(sign: .plus, exponent: -6, significand: 15),
                cacheRead: Decimal(sign: .plus, exponent: -7, significand: 3),
                cacheWrite: nil
            )
        )
    }
}
