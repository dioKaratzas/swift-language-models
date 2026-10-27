import Foundation
import Testing

@testable import ModelCatalogGenerator

@Suite("Catalog snapshot")
struct CatalogSnapshotTests {
    private static let previous = catalogSnapshot(
        catalogModel("vendor/a"),
        catalogModel("vendor/b"),
        catalogModel("vendor/c"),
        catalogModel("vendor/d"),
        catalogModel("vendor/e"),
        removed: [RemovedModel(model: catalogModel("vendor/old"), removedOn: "2026-10-01")],
        vocabularies: [.parameters: [CatalogWord("seed"), CatalogWord("legacy", removedOn: "2026-10-01")]]
    )

    @Test func `a missing model moves to removed with the fetch date`() throws {
        let snapshot = try update(with: Self.models("a", "b", "c", "d"))

        #expect(snapshot.models.map(\.id) == ["vendor/a", "vendor/b", "vendor/c", "vendor/d"])
        #expect(snapshot.removed.map(\.model.id) == ["vendor/e", "vendor/old"])
        #expect(snapshot.removed.first?.removedOn == "2026-10-29")
    }

    @Test func `a model that comes back leaves removed`() throws {
        #expect(try update(with: Self.models("a", "b", "c", "d", "e", "old")).removed.isEmpty)
    }

    @Test func `a source with no models fails`() {
        #expect(throws: GeneratorError.brokenSource("OpenRouter returned no models.")) {
            try update(with: [])
        }
    }

    @Test func `losing more than a fifth of the models at once fails`() {
        #expect(throws: GeneratorError.brokenSource("OpenRouter lost 2 of 5 models at once; nothing was written.")) {
            try update(with: Self.models("a", "b", "c"))
        }
    }

    @Test func `a model listed twice fails`() {
        #expect(throws: GeneratorError.brokenSource("OpenRouter listed these models more than once: vendor/a.")) {
            try update(with: Self.models("a", "a", "b", "c", "d", "e"))
        }
    }

    @Test func `a model that doesn't output text fails`() {
        let models = Self.models("a", "b", "c", "d") + [catalogModel("vendor/e", outputModalities: ["image"])]

        #expect(throws: GeneratorError.brokenSource("OpenRouter listed models that don't output text: vendor/e.")) {
            try update(with: models)
        }
    }

    @Test func `a vocabulary holds the listed words, the words models use and the words that are gone`() throws {
        let fetched = FetchedCatalog(
            models: Self.models("a", "b", "c", "d", "e"),
            vocabularies: [.parameters: [CatalogWord("top_p", summary: "Nucleus sampling.")]],
            efforts: []
        )

        let words = try CatalogSnapshot.updated(source: .openrouter, fetched: fetched, previous: Self.previous, today: "2026-10-29")
            .vocabularies[.parameters]

        #expect(
            words == [
                CatalogWord("legacy", removedOn: "2026-10-01"),
                CatalogWord("seed", removedOn: "2026-10-29"),
                CatalogWord("tools"),
                CatalogWord("top_p", summary: "Nucleus sampling."),
            ]
        )
    }

    @Test func `a snapshot without the request vocabularies still decodes, and a fetch adds their words`() throws {
        let stored = try CatalogJSON.encoded(catalogSnapshot(catalogModel("vendor/a"), vocabularies: [.parameters: [CatalogWord("tools")]]))
        let previous = try JSONDecoder().decode(CatalogSnapshot.self, from: Data(stored.utf8))
        let fetched = FetchedCatalog(
            models: [catalogModel("vendor/a")], vocabularies: [.webSearchEngines: [CatalogWord("exa"), CatalogWord("auto")]], efforts: [])

        let snapshot = try CatalogSnapshot.updated(source: .openrouter, fetched: fetched, previous: previous, today: "2026-10-29")

        #expect(previous.vocabularies[.webSearchEngines] == nil)
        #expect(snapshot.vocabularies[.webSearchEngines] == [CatalogWord("auto"), CatalogWord("exa")])
        #expect(snapshot.vocabularies[.parameters] == [CatalogWord("tools")])
    }

    @Test func `a model priced before the snapshot kept the fees still decodes, without them`() throws {
        let json = #"""
            {"prompt": "0.000001", "completion": "0.000002", "cacheRead": "0.0000001", "overrides": [{"promptTokensAbove": 200000, "prompt": "0.000003"}]}
            """#

        let pricing = try JSONDecoder().decode(CatalogModel.Pricing.self, from: Data(json.utf8))

        #expect(pricing.cacheRead == "0.0000001")
        #expect([pricing.reasoning, pricing.audio, pricing.image, pricing.request, pricing.webSearch] == [nil, nil, nil, nil, nil])
        #expect(pricing.overrides?.map(\.prompt) == ["0.000003"])
        #expect(pricing.overrides?.map(\.audio) == [nil])
    }

    @Test(arguments: [
        (Self.flags(mandatory: true, byDefault: true) as String?, "reasoning", CatalogReasoning.mandatory),
        (Self.flags(mandatory: false, byDefault: true), "reasoning", .optional(enabledByDefault: true)),
        (Self.flags(mandatory: false, byDefault: false), "reasoning", .optional(enabledByDefault: false)),
        (Self.flags(mandatory: false, byDefault: false), "tools", .unsupported),
        (nil, "reasoning", .optional(enabledByDefault: false)),
    ])
    func `a model stored before reasoning was one value decodes it from the flags and parameters`(
        flags: String?,
        parameter: String,
        reasoning: CatalogReasoning
    ) throws {
        let stored = Self.storedModel(flags: flags, parameter: parameter)

        #expect(try JSONDecoder().decode(CatalogModel.self, from: Data(stored.utf8)).reasoning == reasoning)
    }

    @Test func `a snapshot stored before reasoning was one value still decodes`() throws {
        let mandatory = Self.storedModel(flags: Self.flags(mandatory: true, byDefault: true), parameter: "reasoning")
        let gone = Self.storedModel(flags: Self.flags(mandatory: false, byDefault: true), parameter: "reasoning")
        let json = #"""
            {"source": "openrouter", "models": [\#(mandatory)], "removed": [{"model": \#(gone), "removedOn": "2026-10-01"}],
             "vocabularies": {"parameters": [{"word": "reasoning"}]}, "efforts": [], "effortSets": []}
            """#

        let snapshot = try JSONDecoder().decode(CatalogSnapshot.self, from: Data(json.utf8))

        #expect(snapshot.models.map(\.reasoning) == [.mandatory])
        #expect(snapshot.removed.map(\.model.reasoning) == [.optional(enabledByDefault: true)])
    }

    @Test(arguments: CatalogReasoning.allCases)
    func `a model's reasoning is stored as one word and reads back`(reasoning: CatalogReasoning) throws {
        let stored = try CatalogJSON.encoded(catalogModel("vendor/a", parameters: ["reasoning"], reasoning: reasoning))

        #expect(try JSONDecoder().decode(CatalogModel.self, from: Data(stored.utf8)).reasoning == reasoning)
        #expect(!stored.contains("isReasoningMandatory") && !stored.contains("reasonsByDefault"))
    }

    @Test func `a word that comes back is no longer removed`() throws {
        let fetched = FetchedCatalog(
            models: Self.models("a", "b", "c", "d", "e"), vocabularies: [.parameters: [CatalogWord("legacy")]], efforts: [])

        let words = try CatalogSnapshot.updated(source: .openrouter, fetched: fetched, previous: Self.previous, today: "2026-10-29")
            .vocabularies[.parameters]

        #expect(words?.first == CatalogWord("legacy"))
    }

    @Test func `the efforts follow the source's order, keep the words models use and keep the words that are gone`() throws {
        let previous = catalogSnapshot(
            catalogModel("vendor/a"),
            efforts: [CatalogWord("high"), CatalogWord("minimal"), CatalogWord("none")]
        )
        let fetched = FetchedCatalog(
            models: [catalogModel("vendor/a", efforts: ["turbo", "high", "low"], parameters: ["reasoning"])],
            vocabularies: [:],
            efforts: ["high", "low", "none"]
        )

        let snapshot = try CatalogSnapshot.updated(source: .openrouter, fetched: fetched, previous: previous, today: "2026-10-29")

        #expect(
            snapshot.efforts == [
                CatalogWord("turbo"),
                CatalogWord("high"),
                CatalogWord("low"),
                CatalogWord("minimal", removedOn: "2026-10-29"),
                CatalogWord("none"),
            ]
        )
    }

    @Test func `an effort set that no model accepts any more stays, marked removed`() throws {
        let previous = catalogSnapshot(
            catalogModel("vendor/a", efforts: ["high", "medium", "low"], parameters: ["reasoning"]),
            efforts: [CatalogWord("high"), CatalogWord("medium"), CatalogWord("low")],
            effortSets: [CatalogEffortSet(["high", "medium", "low"]), CatalogEffortSet(["high"], removedOn: "2026-10-01")]
        )
        let fetched = FetchedCatalog(
            models: [catalogModel("vendor/a", efforts: ["low", "high"], parameters: ["reasoning"])],
            vocabularies: [:],
            efforts: ["high", "medium", "low"]
        )

        let snapshot = try CatalogSnapshot.updated(source: .openrouter, fetched: fetched, previous: previous, today: "2026-10-29")

        #expect(
            snapshot.effortSets == [
                CatalogEffortSet(["high"], removedOn: "2026-10-01"),
                CatalogEffortSet(["high", "low"]),
                CatalogEffortSet(["high", "medium", "low"], removedOn: "2026-10-29"),
            ]
        )
    }

    @Test func `a removed model's effort set stays in use`() throws {
        let fetched = FetchedCatalog(models: Self.models("a", "b", "c", "d"), vocabularies: [:], efforts: ["high", "low"])
        let previous = catalogSnapshot(
            catalogModel("vendor/a"),
            catalogModel("vendor/b"),
            catalogModel("vendor/c"),
            catalogModel("vendor/d"),
            catalogModel("vendor/e", efforts: ["high", "low"], parameters: ["reasoning"]),
            effortSets: [CatalogEffortSet(["high", "low"])]
        )

        let snapshot = try CatalogSnapshot.updated(source: .openrouter, fetched: fetched, previous: previous, today: "2026-10-29")

        #expect(snapshot.effortSets == [CatalogEffortSet(["high", "low"])])
    }

    /// The reasoning flags that snapshots stored before `reasoning`.
    private static func flags(mandatory: Bool, byDefault: Bool) -> String {
        #""isReasoningMandatory": \#(mandatory), "reasonsByDefault": \#(byDefault)"#
    }

    /// A model as a snapshot written before `reasoning` stores it: with the given flags, if any, and one parameter.
    private static func storedModel(flags: String?, parameter: String) -> String {
        let fields = [
            #""id": "vendor/a", "displayName": "A", "releasedAt": 0, "inputModalities": ["text"], "outputModalities": ["text"]"#,
            #""supportedParameters": ["\#(parameter)"], "reasoningEfforts": []"#,
            flags,
        ]
        return "{\(fields.compactMap(\.self).joined(separator: ", "))}"
    }

    private static func models(_ names: String...) -> [CatalogModel] {
        names.map { catalogModel("vendor/\($0)") }
    }

    private func update(with fetched: [CatalogModel]) throws -> CatalogSnapshot {
        try CatalogSnapshot.updated(
            source: .openrouter,
            fetched: FetchedCatalog(models: fetched, vocabularies: [:], efforts: []),
            previous: Self.previous,
            today: "2026-10-29"
        )
    }
}
