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
        let schema = try CatalogSource.openrouter.schema(of: Bundle.module.fixture("openrouter-models.json"))

        #expect(try CatalogJSON.encoded(schema) == golden("openrouter.schema.json.golden"))
    }

    @Test(arguments: [ReasoningLevelTemplate.path, EffortSetsTemplate.path, OpenRouterModelsTemplate.path])
    func `the snapshot renders the golden source`(path: String) throws {
        #expect(try golden("\(URL(filePath: path).lastPathComponent).golden") == rendered(path, from: fixtureSnapshot()))
    }

    @Test func `rendering twice gives the same files`() throws {
        let snapshot = try fixtureSnapshot()

        #expect(try CatalogRenderer.files(for: [snapshot]) == CatalogRenderer.files(for: [snapshot]))
    }

    @Test func `a removed model keeps a deprecated member and leaves the lookup`() throws {
        let removed = RemovedModel(model: catalogModel("vendor/gone"), removedOn: "2026-10-29")

        let models = try rendered(OpenRouterModelsTemplate.path, from: snapshot(catalogModel("vendor/kept"), removed: [removed]))

        #expect(models.contains(#"@available(*, deprecated, message: "Removed from OpenRouter")"#))
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
        let pricing = CatalogModel.Pricing(prompt: "0.000003", completion: "free", cacheRead: nil, cacheWrite: nil)

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

    private func snapshot(_ models: CatalogModel..., removed: [RemovedModel] = []) -> CatalogSnapshot {
        CatalogSnapshot(source: .openrouter, models: models, removed: removed)
    }

    private func rendered(_ path: String, from snapshot: CatalogSnapshot) throws -> String {
        try #require(try CatalogRenderer.files(for: [snapshot]).first { $0.path == path }).contents
    }
}
