import Foundation
import Testing

@testable import ModelCatalogGenerator

@Suite("Golden files")
struct GoldenFileTests {
    @Test func `the fixture becomes the golden snapshot`() throws {
        #expect(try fixtureSnapshot().encoded() == golden("openrouter.json.golden"))
    }

    @Test(arguments: [ReasoningLevelTemplate.path, EffortSetsTemplate.path, OpenRouterModelsTemplate.path])
    func `the snapshot renders the golden source`(path: String) throws {
        let files = try CatalogRenderer.files(for: [fixtureSnapshot()])
        let file = try #require(files.first { $0.path == path })

        #expect(try golden("\(URL(filePath: path).lastPathComponent).golden") == file.contents)
    }

    @Test func `rendering twice gives the same files`() throws {
        let snapshot = try fixtureSnapshot()

        #expect(try CatalogRenderer.files(for: [snapshot]) == CatalogRenderer.files(for: [snapshot]))
    }

    @Test func `a removed model keeps a deprecated member and leaves the lookup`() throws {
        let snapshot = CatalogSnapshot(
            source: .openrouter,
            models: [catalogModel("vendor/kept")],
            removed: [RemovedModel(model: catalogModel("vendor/gone"), removedOn: "2026-10-29")]
        )

        let file = try #require(try CatalogRenderer.files(for: [snapshot]).last)

        #expect(file.contents.contains(#"@available(*, deprecated, message: "Removed from OpenRouter")"#))
        #expect(file.contents.contains("public static var vendorGone: Self"))
        #expect(file.contents.contains(#"case "vendor/kept":"#))
        #expect(!file.contents.contains(#"case "vendor/gone":"#))
    }

    @Test func `a retiring model is deprecated and stays in the lookup`() throws {
        let snapshot = CatalogSnapshot(
            source: .openrouter,
            models: [catalogModel("vendor/retiring", expirationDate: "2026-12-31")],
            removed: []
        )

        let file = try #require(try CatalogRenderer.files(for: [snapshot]).last)

        #expect(file.contents.contains(#"@available(*, deprecated, message: "OpenRouter retires this model on 2026-12-31")"#))
        #expect(file.contents.contains("public static var vendorRetiring: Self { vendorRetiringEntry }"))
        #expect(file.contents.contains("self.init(OpenRouterModel<Efforts.Unsupported>.vendorRetiringEntry)"))
    }

    @Test func `two models with the same Swift name fail the render`() {
        let snapshot = CatalogSnapshot(
            source: .openrouter,
            models: [catalogModel("vendor/model-1"), catalogModel("vendor/model.1")],
            removed: []
        )

        #expect(throws: GeneratorError.self) {
            try CatalogRenderer.files(for: [snapshot])
        }
    }

    @Test func `a price that isn't a decimal fails the render`() {
        let pricing = CatalogModel.Pricing(prompt: "0.000003", completion: "free", cacheRead: nil, cacheWrite: nil)
        let snapshot = CatalogSnapshot(source: .openrouter, models: [catalogModel("vendor/model", pricing: pricing)], removed: [])

        #expect(throws: GeneratorError.invalidCatalog("OpenRouter model vendor/model has an invalid completion price: 'free'.")) {
            try CatalogRenderer.files(for: [snapshot])
        }
    }
}
