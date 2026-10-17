import Foundation
import LanguageModelsTesting
import Testing

@testable import ModelCatalogGenerator

@Suite("Golden files")
struct GoldenFileTests {
    @Test func `the fixture becomes the golden snapshot`() throws {
        #expect(try CatalogJSON.encoded(fixtureSnapshot()) == golden("openrouter.json.golden"))
    }

    @Test func `the fixture's shape becomes the golden schema`() throws {
        let schema = try CatalogSource.openrouter.schema(of: fixtureDocuments())

        #expect(try CatalogJSON.encoded(schema) == golden("openrouter.schema.json.golden"))
    }

    @Test(
        arguments: [ReasoningLevelTemplate.path, EffortSetsTemplate.path, OpenRouterModelsTemplate.path]
            + CatalogVocabulary.allCases.map { VocabularyTemplate.path(of: $0, from: .openrouter) }
    )
    func `the snapshot renders the golden source`(path: String) throws {
        #expect(try golden("\(URL(filePath: path).lastPathComponent).golden") == rendered(path, from: fixtureSnapshot()))
    }

    @Test func `rendering twice gives the same files`() throws {
        let snapshot = try fixtureSnapshot()

        #expect(try CatalogRenderer.files(for: [snapshot]) == CatalogRenderer.files(for: [snapshot]))
    }

    @Test func `a removed model keeps an unavailable member and leaves the lookup`() throws {
        let removed = RemovedModel(model: catalogModel("vendor/gone"), removedOn: "2026-10-29")

        let models = try rendered(OpenRouterModelsTemplate.path, from: snapshot(catalogModel("vendor/kept"), removed: [removed]))

        #expect(models.contains(#"@available(*, unavailable, message: "Removed from OpenRouter")"#))
        #expect(models.contains("public static var vendorGone: Self"))
        #expect(models.contains(#"case "vendor/kept":"#))
        #expect(!models.contains(#"case "vendor/gone":"#))
    }

    @Test func `a retiring model is deprecated and stays in the lookup`() throws {
        let models = try rendered(
            OpenRouterModelsTemplate.path,
            from: snapshot(catalogModel("vendor/retiring", expirationDate: "2026-12-31"))
        )

        #expect(models.contains(#"@available(*, deprecated, message: "OpenRouter retires this model on 2026-12-31")"#))
        #expect(models.contains("public static var vendorRetiring: Self { vendorRetiringEntry }"))
        #expect(models.contains("self.init(OpenRouterModel<Efforts.Unsupported>.vendorRetiringEntry)"))
    }

    @Test func `two models with the same Swift name fail the render`() {
        #expect(throws: GeneratorError.self) {
            try CatalogRenderer.files(for: [snapshot(catalogModel("vendor/model-1"), catalogModel("vendor/model.1"))])
        }
    }

    @Test func `a price that isn't a decimal fails the render`() {
        let pricing = CatalogModel.Pricing(prompt: "0.000003", completion: "free", cacheRead: nil, cacheWrite: nil, overrides: nil)

        #expect(throws: GeneratorError.invalidCatalog("OpenRouter model vendor/model has an invalid completion price: 'free'.")) {
            try CatalogRenderer.files(for: [snapshot(catalogModel("vendor/model", pricing: pricing))])
        }
    }

    @Test func `a default effort the model doesn't list fails the render`() {
        let model = catalogModel("vendor/model", efforts: ["high", "low"], defaultEffort: "medium", parameters: ["reasoning"])

        #expect(throws: GeneratorError.self) {
            try CatalogRenderer.files(for: [snapshot(model)])
        }
    }

    @Test(arguments: [
        Self.override(weekdays: ["someday"]),
        Self.override(startTime: 2_500),
        Self.override(endTime: 1_260),
    ])
    func `an override condition that isn't a day or a time fails the render`(override: CatalogModel.Pricing.Override) {
        let pricing = CatalogModel.Pricing(
            prompt: "0.000003", completion: "0.000015", cacheRead: nil, cacheWrite: nil, overrides: [override])

        #expect(throws: GeneratorError.self) {
            try CatalogRenderer.files(for: [snapshot(catalogModel("vendor/model", pricing: pricing))])
        }
    }

    @Test func `a removed word keeps an unavailable member`() throws {
        let words = [CatalogWord("seed"), CatalogWord("legacy_seed", removedOn: "2026-10-29")]

        let parameters = try rendered(
            VocabularyTemplate.path(of: .parameters, from: .openrouter),
            from: snapshot(catalogModel("vendor/model"), vocabularies: [.parameters: words])
        )

        #expect(
            parameters.contains(
                """
                    /// The `legacy_seed` parameter.
                    @available(*, unavailable, message: "Removed from OpenRouter")
                    public static let legacySeed: Self = "legacy_seed"
                """
            )
        )
    }

    @Test func `two words with the same Swift name fail the render`() {
        let words = [CatalogWord("top_p"), CatalogWord("top-p")]

        #expect(throws: GeneratorError.self) {
            try CatalogRenderer.files(for: [snapshot(catalogModel("vendor/model"), vocabularies: [.parameters: words])])
        }
    }

    private func snapshot(
        _ models: CatalogModel...,
        removed: [RemovedModel] = [],
        vocabularies: [CatalogVocabulary: [CatalogWord]] = [:]
    ) -> CatalogSnapshot {
        CatalogSnapshot(source: .openrouter, models: models, removed: removed, vocabularies: vocabularies)
    }

    private static func override(weekdays: [String]? = nil, startTime: Int? = nil, endTime: Int? = nil) -> CatalogModel.Pricing.Override {
        CatalogModel.Pricing.Override(
            promptTokensAbove: nil,
            weekdays: weekdays,
            startTime: startTime,
            endTime: endTime,
            prompt: "0.000001",
            completion: nil,
            cacheRead: nil,
            cacheWrite: nil
        )
    }

    private func rendered(_ path: String, from snapshot: CatalogSnapshot) throws -> String {
        try #require(try CatalogRenderer.files(for: [snapshot]).first { $0.path == path }).contents
    }
}
