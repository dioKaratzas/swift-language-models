import Foundation
import LanguageModelsTestSupport
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
        arguments: [
            ReasoningLevelTemplate.path, OpenRouterModelsTemplate.path, ModelEffortsTemplate.path(for: .openrouter),
            ModelRemovalsTemplate.path(for: .openrouter),
        ] + CatalogSource.openrouter.vocabularies.map { VocabularyTemplate.path(of: $0, from: .openrouter) }
    )
    func `the snapshot renders the golden source`(path: String) throws {
        #expect(try golden("\(URL(filePath: path).lastPathComponent).golden") == rendered(path, from: fixtureSnapshot()))
    }

    @Test func `a source's snapshot renders a file for each of the source's vocabularies, and no others`() throws {
        let snapshot = catalogSnapshot(catalogModel("vendor/model"), vocabularies: [.parameters: [CatalogWord("tools")]])

        let paths = try CatalogRenderer.files(for: [snapshot]).map(\.path)

        #expect(
            paths == [ReasoningLevelTemplate.path]
                + CatalogSource.openrouter.vocabularies.map { VocabularyTemplate.path(of: $0, from: .openrouter) }
                + [
                    OpenRouterModelsTemplate.path, ModelEffortsTemplate.path(for: .openrouter),
                    ModelRemovalsTemplate.path(for: .openrouter),
                ]
        )
    }

    @Test func `rendering twice gives the same files`() throws {
        let snapshot = try fixtureSnapshot()

        #expect(try CatalogRenderer.files(for: [snapshot]) == CatalogRenderer.files(for: [snapshot]))
    }

    @Test func `a removed model keeps a deprecated member and leaves the lookup`() throws {
        let removed = RemovedModel(model: catalogModel("vendor/gone"), removedOn: "2026-10-29")

        let models = try rendered(OpenRouterModelsTemplate.path, from: catalogSnapshot(catalogModel("vendor/kept"), removed: [removed]))

        #expect(models.contains(#"@available(*, deprecated, message: "Removed from OpenRouter on 2026-10-29")"#))
        #expect(models.contains("public static var vendorGone: Self"))
        #expect(models.contains(#"case "vendor/kept":"#))
        #expect(!models.contains(#"case "vendor/gone":"#))
    }

    @Test func `the removals list each removed model with the day it left, by id`() throws {
        let removed = [
            RemovedModel(model: catalogModel("vendor/gone"), removedOn: "2026-10-29"),
            RemovedModel(model: catalogModel("vendor/also-gone"), removedOn: "2026-10-31"),
        ]

        let removals = try rendered(
            ModelRemovalsTemplate.path(for: .openrouter), from: catalogSnapshot(catalogModel("vendor/kept"), removed: removed))

        #expect(
            removals.contains(
                """
                    static let openRouter = ModelRemovals([
                        "vendor/also-gone": Date(timeIntervalSince1970: 1_793_404_800),
                        "vendor/gone": Date(timeIntervalSince1970: 1_793_232_000),
                    ])
                """
            )
        )
    }

    @Test func `a retiring model is deprecated and stays in the lookup`() throws {
        let models = try rendered(
            OpenRouterModelsTemplate.path,
            from: catalogSnapshot(catalogModel("vendor/retiring", expirationDate: "2026-12-31"))
        )

        #expect(models.contains(#"@available(*, deprecated, message: "OpenRouter retires this model on 2026-12-31")"#))
        #expect(models.contains("public static var vendorRetiring: Self { vendorRetiringEntry }"))
        #expect(models.contains("self.init(OpenRouterModel<_>.vendorRetiringEntry)"))
    }

    @Test func `a retiring model whose name needs backticks keeps its data member inside them`() throws {
        let models = try rendered(
            OpenRouterModelsTemplate.path,
            from: catalogSnapshot(catalogModel("01-ai/yi-large", expirationDate: "2026-12-31"))
        )

        #expect(models.contains("public static var `01AiYiLarge`: Self { `01AiYiLargeEntry` }"))
        #expect(models.contains("self.init(OpenRouterModel<_>.`01AiYiLargeEntry`)"))
    }

    @Test func `the list has the models the lookup finds, with a retiring one through its data member`() throws {
        let removed = RemovedModel(model: catalogModel("vendor/gone"), removedOn: "2026-10-29")
        let snapshot = catalogSnapshot(
            catalogModel("vendor/retiring", expirationDate: "2026-12-31"),
            catalogModel("vendor/kept"),
            removed: [removed]
        )

        let models = try rendered(OpenRouterModelsTemplate.path, from: snapshot)

        #expect(
            models.contains(
                """
                    public static var catalogModels: [Self] {
                        [
                            Self(OpenRouterModel<_>.vendorKept),
                            Self(OpenRouterModel<_>.vendorRetiringEntry),
                        ]
                    }
                """
            )
        )
        #expect(!models.contains("Self(OpenRouterModel<_>.vendorGone)"))
    }

    @Test func `the lookup switches on the id's text`() throws {
        let models = try rendered(OpenRouterModelsTemplate.path, from: catalogSnapshot(catalogModel("vendor/model")))

        #expect(models.contains("        switch id.rawValue {\n        case \"vendor/model\":"))
    }

    @Test(arguments: [
        catalogModel("vendor/model", displayName: "Model\n    public static var injected: Self { fatalError() }"),
        catalogModel("vendor/model", displayName: "Model\u{2028}public static var injected: Self { fatalError() }"),
        catalogModel("vendor/model", aliasTarget: "vendor/target`\r\npublic static var injected: Self { fatalError() }"),
    ])
    func `a name with a line break can't inject code`(model: CatalogModel) throws {
        let lines = try rendered(OpenRouterModelsTemplate.path, from: catalogSnapshot(model)).split(separator: "\n")

        #expect(!lines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("public static var injected") })
    }

    @Test func `a vocabulary word with a line break can't inject code`() throws {
        let words = [CatalogWord("seed", summary: "Seed.\npublic static let injected: Self = \"x\"")]

        let parameters = try rendered(
            VocabularyTemplate.path(of: .parameters, from: .openrouter),
            from: catalogSnapshot(catalogModel("vendor/model"), vocabularies: [.parameters: words])
        )

        #expect(parameters.contains(#"    /// Seed. public static let injected: Self = "x""#))
    }

    @Test(arguments: [["none", "off"], ["high", "High"]])
    func `two effort words with the same Swift name fail the render`(words: [String]) {
        let model = catalogModel("vendor/model", efforts: words, parameters: ["reasoning"])
        let message = "These effort words get the same Swift name: \(words.sorted().joined(separator: ", "))."

        #expect(throws: GeneratorError.invalidCatalog(message)) {
            try CatalogRenderer.files(for: [catalogSnapshot(model)])
        }
    }

    @Test(arguments: ["light", "moderate", "deep", "custom", "effort_ranking"])
    func `an effort word whose name the reasoning level already has fails the render`(word: String) {
        let model = catalogModel("vendor/model", efforts: [word], parameters: ["reasoning"])

        #expect(throws: GeneratorError.invalidCatalog("These effort words get a Swift name that's taken: \(word).")) {
            try CatalogRenderer.files(for: [catalogSnapshot(model)])
        }
    }

    @Test(arguments: ["all_cases", "raw_value", "reasoning_level", "hash_value"])
    func `an effort word whose name a model's effort type already has fails the render`(word: String) {
        let model = catalogModel("vendor/model", efforts: [word], parameters: ["reasoning"])

        #expect(throws: GeneratorError.invalidCatalog("These effort words get a Swift name that's taken: \(word).")) {
            try CatalogRenderer.files(for: [catalogSnapshot(model)])
        }
    }

    @Test(arguments: ["~/-", "ü/ö"])
    func `a model id without ASCII letters or digits in it fails the render`(id: String) {
        #expect(throws: GeneratorError.invalidCatalog("These OpenRouter models get no Swift name: \(id).")) {
            try CatalogRenderer.files(for: [catalogSnapshot(catalogModel(id))])
        }
    }

    @Test(arguments: ["none", "some"])
    func `a model named like an optional's case fails the render`(id: String) {
        #expect(throws: GeneratorError.invalidCatalog("These OpenRouter models get a Swift name that's taken: \(id).")) {
            try CatalogRenderer.files(for: [catalogSnapshot(catalogModel(id))])
        }
    }

    @Test(arguments: ["none", "some"])
    func `a vocabulary word named like an optional's case fails the render`(word: String) {
        let snapshot = catalogSnapshot(catalogModel("vendor/model"), vocabularies: [.webSearchModes: [CatalogWord(word)]])

        #expect(throws: GeneratorError.invalidCatalog("These OpenRouterWebSearchMode words get a Swift name that's taken: \(word).")) {
            try CatalogRenderer.files(for: [snapshot])
        }
    }

    @Test func `two models with the same Swift name fail the render`() {
        let message = "These OpenRouter models get the same Swift name: vendor/model-1, vendor/model.1."

        #expect(throws: GeneratorError.invalidCatalog(message)) {
            try CatalogRenderer.files(for: [catalogSnapshot(catalogModel("vendor/model-1"), catalogModel("vendor/model.1"))])
        }
    }

    @Test func `a removed effort word keeps a deprecated member`() throws {
        let model = catalogModel("vendor/model", efforts: ["high", "low"], parameters: ["reasoning"])
        let efforts = [CatalogWord("high"), CatalogWord("medium", removedOn: "2026-10-29"), CatalogWord("low")]

        let levels = try rendered(ReasoningLevelTemplate.path, from: catalogSnapshot(model, efforts: efforts))

        #expect(
            levels.contains(
                """
                    /// The `medium` effort.
                    @available(*, deprecated, message: "Removed from OpenRouter")
                    public static var medium: Self { .custom("medium") }
                """
            )
        )
        #expect(levels.contains(#"package static let effortRanking = ["high", "medium", "low"]"#))
    }

    @Test func `a model's levels are members of its own effort type, and a level it stopped accepting stays deprecated`() throws {
        let model = catalogModel(
            "vendor/model", efforts: ["high", "low"], parameters: ["reasoning"],
            removedEfforts: [CatalogWord("medium", removedOn: "2026-10-29")]
        )
        let snapshot = catalogSnapshot(model, efforts: [CatalogWord("high"), CatalogWord("medium"), CatalogWord("low")])

        let efforts = try rendered(ModelEffortsTemplate.path(for: .openrouter), from: snapshot)

        #expect(
            efforts.contains(
                """
                    public enum VendorModel: ModelEffortList {
                        public static var efforts: [String] { ["high", "low"] }
                        public static var removedEfforts: [String] { ["medium"] }
                    }
                """
            )
        )
        #expect(
            efforts.contains(
                """
                extension Efforts.Of where Model == OpenRouterModels.VendorModel {
                    /// The `high` effort.
                    public static var high: Self { Self(listed: "high") }

                    /// The `medium` effort.
                    @available(*, deprecated, message: "OpenRouter stopped accepting this level for this model on 2026-10-29")
                    public static var medium: Self { Self(listed: "medium") }

                    /// The `low` effort.
                    public static var low: Self { Self(listed: "low") }
                }
                """
            )
        )
        #expect(
            try rendered(OpenRouterModelsTemplate.path, from: snapshot)
                .contains("extension OpenRouterModel where Effort == Efforts.Of<OpenRouterModels.VendorModel> {")
        )
    }

    @Test func `a model without levels still gets an effort type of its own, with no members`() throws {
        let efforts = try rendered(ModelEffortsTemplate.path(for: .openrouter), from: catalogSnapshot(catalogModel("vendor/plain")))

        #expect(
            efforts.contains(
                """
                    public enum VendorPlain: ModelEffortList {
                        public static var efforts: [String] { [] }
                    }
                """
            )
        )
        #expect(!efforts.contains("extension Efforts.Of"))
    }

    @Test func `a default effort the model doesn't list fails the render`() {
        let model = catalogModel("vendor/model", efforts: ["high", "low"], defaultEffort: "medium", parameters: ["reasoning"])

        #expect(
            throws: GeneratorError.invalidCatalog(
                "OpenRouter model vendor/model defaults to the effort 'medium', which it doesn't list."
            )
        ) {
            try CatalogRenderer.files(for: [catalogSnapshot(model)])
        }
    }

    @Test func `a removed word keeps a deprecated member with its day`() throws {
        let words = [CatalogWord("seed"), CatalogWord("legacy_seed", removedOn: "2026-10-29")]

        let parameters = try rendered(
            VocabularyTemplate.path(of: .parameters, from: .openrouter),
            from: catalogSnapshot(catalogModel("vendor/model"), vocabularies: [.parameters: words])
        )

        #expect(
            parameters.contains(
                """
                    /// The `legacy_seed` parameter.
                    @available(*, deprecated, message: "Removed from OpenRouter on 2026-10-29")
                    public static let legacySeed: Self = "legacy_seed"
                """
            )
        )
    }

    @Test func `two words with the same Swift name fail the render`() {
        let words = [CatalogWord("top_p"), CatalogWord("top-p")]

        #expect(throws: GeneratorError.invalidCatalog("These OpenRouterParameter words get the same Swift name: top-p, top_p.")) {
            try CatalogRenderer.files(for: [catalogSnapshot(catalogModel("vendor/model"), vocabularies: [.parameters: words])])
        }
    }

    private func rendered(_ path: String, from snapshot: CatalogSnapshot) throws -> String {
        try #require(try CatalogRenderer.files(for: [snapshot]).first { $0.path == path }).contents
    }
}
