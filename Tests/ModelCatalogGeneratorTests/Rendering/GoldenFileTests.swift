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
        arguments: [ReasoningLevelTemplate.path, EffortSetsTemplate.path, OpenRouterModelsTemplate.path]
            + CatalogSource.openrouter.vocabularies.map { VocabularyTemplate.path(of: $0, from: .openrouter) }
    )
    func `the snapshot renders the golden source`(path: String) throws {
        #expect(try golden("\(URL(filePath: path).lastPathComponent).golden") == rendered(path, from: fixtureSnapshot()))
    }

    @Test func `a source's snapshot renders a file for each of the source's vocabularies, and no others`() throws {
        let snapshot = catalogSnapshot(catalogModel("vendor/model"), vocabularies: [.parameters: [CatalogWord("tools")]])

        let paths = try CatalogRenderer.files(for: [snapshot]).map(\.path)

        #expect(
            paths == [ReasoningLevelTemplate.path, EffortSetsTemplate.path]
                + CatalogSource.openrouter.vocabularies.map { VocabularyTemplate.path(of: $0, from: .openrouter) }
                + [OpenRouterModelsTemplate.path]
        )
    }

    @Test func `rendering twice gives the same files`() throws {
        let snapshot = try fixtureSnapshot()

        #expect(try CatalogRenderer.files(for: [snapshot]) == CatalogRenderer.files(for: [snapshot]))
    }

    @Test func `a removed model keeps an unavailable member and leaves the lookup`() throws {
        let removed = RemovedModel(model: catalogModel("vendor/gone"), removedOn: "2026-10-29")

        let models = try rendered(OpenRouterModelsTemplate.path, from: catalogSnapshot(catalogModel("vendor/kept"), removed: [removed]))

        #expect(models.contains(#"@available(*, unavailable, message: "Removed from OpenRouter")"#))
        #expect(models.contains("public static var vendorGone: Self"))
        #expect(models.contains(#"case "vendor/kept":"#))
        #expect(!models.contains(#"case "vendor/gone":"#))
    }

    @Test func `a retiring model is deprecated and stays in the lookup`() throws {
        let models = try rendered(
            OpenRouterModelsTemplate.path,
            from: catalogSnapshot(catalogModel("vendor/retiring", expirationDate: "2026-12-31"))
        )

        #expect(models.contains(#"@available(*, deprecated, message: "OpenRouter retires this model on 2026-12-31")"#))
        #expect(models.contains("public static var vendorRetiring: Self { vendorRetiringEntry }"))
        #expect(models.contains("self.init(OpenRouterModel<Efforts.Unsupported>.vendorRetiringEntry)"))
    }

    @Test func `a retiring model whose name needs backticks keeps its data member inside them`() throws {
        let models = try rendered(
            OpenRouterModelsTemplate.path,
            from: catalogSnapshot(catalogModel("01-ai/yi-large", expirationDate: "2026-12-31"))
        )

        #expect(models.contains("public static var `01AiYiLarge`: Self { `01AiYiLargeEntry` }"))
        #expect(models.contains("self.init(OpenRouterModel<Efforts.Unsupported>.`01AiYiLargeEntry`)"))
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
                            Self(OpenRouterModel<Efforts.Unsupported>.vendorKept),
                            Self(OpenRouterModel<Efforts.Unsupported>.vendorRetiringEntry),
                        ]
                    }
                """
            )
        )
        #expect(!models.contains("Self(OpenRouterModel<Efforts.Unsupported>.vendorGone)"))
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

    @Test func `an effort set named like the unsupported effort fails the render`() {
        let model = catalogModel("vendor/model", efforts: ["unsupported"], parameters: ["reasoning"])

        #expect(throws: GeneratorError.invalidCatalog("These effort sets get a Swift name that's taken: unsupported.")) {
            try CatalogRenderer.files(for: [catalogSnapshot(model)])
        }
    }

    @Test func `two effort sets with the same type name fail the render`() {
        let snapshot = catalogSnapshot(
            catalogModel("vendor/a", efforts: ["max", "high"], parameters: ["reasoning"]),
            catalogModel("vendor/b", efforts: ["max-high"], parameters: ["reasoning"]),
            efforts: [CatalogWord("max"), CatalogWord("high")]
        )

        #expect(throws: GeneratorError.invalidCatalog("These effort sets get the same Swift name: max high, max-high.")) {
            try CatalogRenderer.files(for: [snapshot])
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

    @Test func `a removed effort word keeps an unavailable member`() throws {
        let model = catalogModel("vendor/model", efforts: ["high", "low"], parameters: ["reasoning"])
        let efforts = [CatalogWord("high"), CatalogWord("medium", removedOn: "2026-10-29"), CatalogWord("low")]

        let levels = try rendered(ReasoningLevelTemplate.path, from: catalogSnapshot(model, efforts: efforts))

        #expect(
            levels.contains(
                """
                    /// The `medium` effort.
                    @available(*, unavailable, message: "Removed from OpenRouter")
                    public static var medium: Self { .custom("medium") }
                """
            )
        )
        #expect(levels.contains(#"package static let effortRanking = ["high", "medium", "low"]"#))
    }

    @Test func `an effort set no model accepts any more keeps an unavailable enum`() throws {
        let model = catalogModel("vendor/model", efforts: ["high", "low"], parameters: ["reasoning"])
        let sets = [CatalogEffortSet(["high", "low"]), CatalogEffortSet(["high", "medium", "low"], removedOn: "2026-10-29")]

        let efforts = try rendered(EffortSetsTemplate.path, from: catalogSnapshot(model, effortSets: sets))

        #expect(
            efforts.contains(
                """
                    @available(*, unavailable, message: "Removed from OpenRouter")
                    public enum HighMediumLow: String, ModelEffort, CaseIterable, Codable {
                """
            )
        )
        #expect(efforts.contains("    public enum HighLow: String, ModelEffort, CaseIterable, Codable {"))
    }

    @Test func `an effort set that a model accepts again is available`() throws {
        let model = catalogModel("vendor/model", efforts: ["high", "low"], parameters: ["reasoning"])

        let efforts = try rendered(
            EffortSetsTemplate.path,
            from: catalogSnapshot(model, effortSets: [CatalogEffortSet(["high", "low"], removedOn: "2026-10-01")])
        )

        #expect(!efforts.contains("@available"))
    }

    @Test func `a price that isn't a decimal fails the render`() {
        let pricing = Self.pricing(completion: "free")

        #expect(throws: GeneratorError.invalidCatalog("OpenRouter model vendor/model has an invalid completion price: 'free'.")) {
            try CatalogRenderer.files(for: [catalogSnapshot(catalogModel("vendor/model", pricing: pricing))])
        }
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

    @Test(arguments: [
        (Self.override(startTime: 2_500), "start time: '2500'"),
        (Self.override(endTime: 1_260), "end time: '1260'"),
    ])
    func `an override time that isn't a clock time fails the render`(
        override: CatalogModel.Pricing.Override,
        invalid: String
    ) {
        let message = "OpenRouter model vendor/model has an invalid override \(invalid)."
        #expect(throws: GeneratorError.invalidCatalog(message)) {
            try CatalogRenderer.files(for: [catalogSnapshot(catalogModel("vendor/model", pricing: Self.pricing(overrides: [override])))])
        }
    }

    @Test(arguments: [
        (Self.override(startTime: 0), "hours: .init(start: .seconds(0), end: .seconds(86_400))"),
        (Self.override(startTime: 1_600), "hours: .init(start: .seconds(57_600), end: .seconds(86_400))"),
        (Self.override(endTime: 400), "hours: .init(start: .seconds(0), end: .seconds(14_400))"),
    ])
    func `a window with one end missing runs from or to midnight`(override: CatalogModel.Pricing.Override, hours: String) throws {
        let models = try rendered(
            OpenRouterModelsTemplate.path,
            from: catalogSnapshot(catalogModel("vendor/model", pricing: Self.pricing(overrides: [override])))
        )

        #expect(models.contains(hours))
    }

    @Test func `an override's weekdays become the weekdays of the condition`() throws {
        let override = Self.override(weekdays: [.saturday, .sunday])

        let models = try rendered(
            OpenRouterModelsTemplate.path,
            from: catalogSnapshot(catalogModel("vendor/model", pricing: Self.pricing(overrides: [override])))
        )

        #expect(models.contains("condition: .init(weekdays: [.saturday, .sunday])"))
    }

    @Test func `a removed word keeps an unavailable member`() throws {
        let words = [CatalogWord("seed"), CatalogWord("legacy_seed", removedOn: "2026-10-29")]

        let parameters = try rendered(
            VocabularyTemplate.path(of: .parameters, from: .openrouter),
            from: catalogSnapshot(catalogModel("vendor/model"), vocabularies: [.parameters: words])
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

        #expect(throws: GeneratorError.invalidCatalog("These OpenRouterParameter words get the same Swift name: top-p, top_p.")) {
            try CatalogRenderer.files(for: [catalogSnapshot(catalogModel("vendor/model"), vocabularies: [.parameters: words])])
        }
    }

    private static func pricing(
        completion: String = "0.000015",
        overrides: [CatalogModel.Pricing.Override]? = nil
    ) -> CatalogModel.Pricing {
        CatalogModel.Pricing(
            prompt: "0.000003",
            completion: completion,
            cacheRead: nil,
            cacheWrite: nil,
            cacheWriteOneHour: nil,
            reasoning: nil,
            audio: nil,
            image: nil,
            request: nil,
            webSearch: nil,
            overrides: overrides
        )
    }

    private static func override(
        weekdays: [CatalogModel.Pricing.Override.Weekday]? = nil,
        startTime: Int? = nil,
        endTime: Int? = nil
    ) -> CatalogModel.Pricing.Override {
        CatalogModel.Pricing.Override(
            promptTokensAbove: nil,
            weekdays: weekdays,
            startTime: startTime,
            endTime: endTime,
            prompt: "0.000001",
            completion: nil,
            cacheRead: nil,
            cacheWrite: nil,
            cacheWriteOneHour: nil,
            audio: nil
        )
    }

    private func rendered(_ path: String, from snapshot: CatalogSnapshot) throws -> String {
        try #require(try CatalogRenderer.files(for: [snapshot]).first { $0.path == path }).contents
    }
}
