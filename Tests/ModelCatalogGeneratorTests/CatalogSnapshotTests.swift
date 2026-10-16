import Testing

@testable import ModelCatalogGenerator

@Suite("Catalog snapshot")
struct CatalogSnapshotTests {
    private static let previous = CatalogSnapshot(
        source: .openrouter,
        models: models("a", "b", "c", "d", "e"),
        removed: [RemovedModel(model: catalogModel("vendor/old"), removedOn: "2026-10-01")]
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

    private static func models(_ names: String...) -> [CatalogModel] {
        names.map { catalogModel("vendor/\($0)") }
    }

    private func update(with fetched: [CatalogModel]) throws -> CatalogSnapshot {
        try CatalogSnapshot.updated(source: .openrouter, fetched: fetched, previous: Self.previous, today: "2026-10-29")
    }
}
