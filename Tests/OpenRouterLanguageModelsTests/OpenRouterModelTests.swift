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
        #expect(open.pricing == typed.pricing)
    }

    @Test func `the catalog lookup gives nil for an unknown id`() {
        #expect(OpenRouterModel(catalogID: "vendor/not-a-model") == nil)
    }

    private func model(parameters: Set<String>, inputs: Set<String>) -> OpenRouterModel<Efforts.MaxHighLowOff> {
        OpenRouterModel(
            id: "vendor/model",
            displayName: "Vendor: Model",
            contextSize: 200_000,
            maximumResponseTokens: 8_192,
            inputModalities: inputs,
            supportedParameters: parameters,
            reasoningEfforts: [.max, .low, .off],
            defaultReasoningEffort: .low,
            pricing: OpenRouterPricing(
                prompt: Decimal(sign: .plus, exponent: -6, significand: 3),
                completion: Decimal(sign: .plus, exponent: -6, significand: 15)
            )
        )
    }
}
