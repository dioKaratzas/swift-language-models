import Testing

@testable import ModelCatalogGenerator

@Suite("Catalog snapshot")
struct CatalogSnapshotTests {
    private static let previous = CatalogSnapshot(
        source: .openrouter,
        models: models("a", "b", "c", "d", "e"),
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
        #expect(throws: GeneratorError.self) {
            try update(with: [])
        }
    }

    @Test func `losing more than a fifth of the models at once fails`() {
        #expect(throws: GeneratorError.self) {
            try update(with: Self.models("a", "b", "c"))
        }
    }

    @Test func `a vocabulary holds the listed words, the words models use and the words that are gone`() throws {
        let fetched = FetchedCatalog(
            models: Self.models("a", "b", "c", "d", "e"),
            vocabularies: [.parameters: [CatalogWord("top_p", summary: "Nucleus sampling.")]]
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

    @Test func `a word that comes back is no longer removed`() throws {
        let fetched = FetchedCatalog(models: Self.models("a", "b", "c", "d", "e"), vocabularies: [.parameters: [CatalogWord("legacy")]])

        let words = try CatalogSnapshot.updated(source: .openrouter, fetched: fetched, previous: Self.previous, today: "2026-10-29")
            .vocabularies[.parameters]

        #expect(words?.first == CatalogWord("legacy"))
    }

    private static func models(_ names: String...) -> [CatalogModel] {
        names.map { catalogModel("vendor/\($0)") }
    }

    private func update(with fetched: [CatalogModel]) throws -> CatalogSnapshot {
        try CatalogSnapshot.updated(
            source: .openrouter,
            fetched: FetchedCatalog(models: fetched, vocabularies: [:]),
            previous: Self.previous,
            today: "2026-10-29"
        )
    }
}
