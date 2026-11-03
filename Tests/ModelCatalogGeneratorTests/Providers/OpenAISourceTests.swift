import Foundation
import LanguageModelsTestSupport
import Testing

@testable import ModelCatalogGenerator

@Suite("OpenAI source")
struct OpenAISourceTests {
    @Test func `the catalog lists the served Responses models that models.dev describes as text models, and none shut down`() throws {
        let snapshot = try openAIFixtureSnapshot()

        #expect(snapshot.models.map(\.id) == ["gpt-4o", "gpt-4o-2024-11-20", "gpt-6-astra", "gpt-6-luna", "o3"])
    }

    @Test func `a dated snapshot that models.dev doesn't list takes its model's description and name, with its day`() throws {
        let models = try openAIFixtureSnapshot().models
        let snapshot = try #require(models.first { $0.id == "gpt-4o-2024-11-20" })
        let model = try #require(models.first { $0.id == "gpt-4o" })

        #expect(snapshot.displayName == "GPT-4o (2024-11-20)")
        #expect(snapshot.supportedParameters == model.supportedParameters)
        #expect(snapshot.releasedAt != model.releasedAt)
    }

    @Test func `a model that takes none reasons until a request turns it off, and one that doesn't always reasons`() throws {
        let models = try openAIFixtureSnapshot().models

        #expect(models.first { $0.id == "gpt-6-luna" }?.reasoning == .optional(enabledByDefault: true))
        #expect(models.first { $0.id == "gpt-6-astra" }?.reasoning == .mandatory)
        #expect(models.first { $0.id == "gpt-4o" }?.reasoning == .unsupported)
        #expect(models.first { $0.id == "o3" }?.reasoningEfforts == ["high", "medium", "low"])
        #expect(models.first { $0.id == "o3" }?.defaultReasoningEffort == "medium")
    }

    @Test func `the efforts come from the API description, highest first`() throws {
        #expect(try openAIFixtureSnapshot().efforts.map(\.word) == ["max", "xhigh", "high", "medium", "low", "minimal", "none"])
    }

    @Test func `a model whose shutdown day is today is still listed, with the day as its expiration`() throws {
        let catalog = try CatalogSource.openai.catalog(from: openAIFixtureDocuments(), today: "2026-10-23")

        #expect(catalog.models.first { $0.id == "o4-mini" }?.expirationDate == "2026-10-23")
    }

    @Test func `fetching OpenAI's models without an API key fails before any request`() async {
        let stub = HTTPStub()

        await #expect(throws: GeneratorError.brokenSource("OpenAI's model list needs an API key: set OPENAI_API_KEY to fetch it.")) {
            _ = try await CatalogSource.openai.documents(using: stub.session, baseURL: stub.baseURL, environment: [:])
        }
        #expect(stub.requests.isEmpty)
    }
}
