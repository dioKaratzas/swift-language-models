import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

/// OpenRouter's lists of a model's providers and current details, read without an API key, to check that today's
/// answers still decode. It runs only with `LIVE_INFO` set, and costs nothing.
@Suite(
    "Live: OpenRouter model info",
    .tags(.live),
    .enabled(if: ProcessInfo.processInfo.environment["LIVE_INFO"]?.isEmpty == false, "Set LIVE_INFO to read OpenRouter's model info"),
    .timeLimit(.minutes(1))
)
struct LiveInfoTests {
    @Test func `a model's providers decode with their slugs, limits and prices`() async throws {
        let providers = try await OpenRouterModel.anthropicClaudeHaiku5_5.providers()

        #expect(!providers.isEmpty)
        #expect(providers.allSatisfy { !$0.name.isEmpty && !$0.tag.rawValue.isEmpty })
        #expect(providers.allSatisfy { $0.modelID == "anthropic/claude-haiku-5.5" })
        #expect(providers.contains { $0.tag == "anthropic" })
        #expect(providers.allSatisfy { ($0.pricing?.prompt ?? 0) > 0 })
        #expect(providers.allSatisfy { ($0.contextSize ?? 0) > 0 })
        #expect(providers.allSatisfy { $0.supportedParameters.contains(.tools) })
        #expect(providers.allSatisfy { ($0.uptimeLastDay ?? 100) <= 100 })
        #expect(providers.allSatisfy { (0...1).contains($0.discount) })
    }

    @Test func `a model's current details decode with its prices and limits`() async throws {
        let details = try await OpenRouterModel.anthropicClaudeHaiku5_5.currentDetails()

        #expect(details.id == "anthropic/claude-haiku-5.5")
        #expect((details.pricing?.prompt ?? 0) > 0)
        #expect((details.contextSize ?? 0) > 0)
        #expect((details.maximumOutputTokens ?? 0) > 0)
        #expect(details.supportedParameters.contains(.tools))
    }

    @Test func `a router has no pricing, and an alias names its target`() async throws {
        let router = try await Self.model("openrouter/auto").currentPricing()
        let alias = try await Self.model("~anthropic/claude-haiku-latest").currentDetails()

        #expect(router == nil)
        #expect(alias.aliasTarget != nil)
    }

    @Test func `a model OpenRouter doesn't list throws a not found error`() async throws {
        let error = await #expect(throws: OpenRouterError.self) { try await Self.model("vendor/no-such-model").currentDetails() }

        #expect(error?.code == .notFound)
    }

    /// A model that isn't in the catalog.
    private static func model(_ id: OpenRouterModelID) -> OpenRouterModel<ContextOptions.ReasoningLevel> {
        OpenRouterModel(id: id, displayName: id.rawValue, releaseDate: .now, supportedParameters: [])
    }
}
