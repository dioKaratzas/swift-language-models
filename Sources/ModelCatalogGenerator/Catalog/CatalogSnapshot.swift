/// A source's models as `Catalogs/<source>.json` stores them, sorted so the file's diff reads as a changelog.
struct CatalogSnapshot: Codable, Equatable, Sendable {
    let source: CatalogSource
    let models: [CatalogModel]
    let removed: [RemovedModel]

    /// The snapshot after a fetch: new and changed models replace old ones, and missing models move to `removed`.
    ///
    /// - Parameters:
    ///   - source: The source the models came from.
    ///   - fetched: The models the source returned.
    ///   - previous: The snapshot in the package, if any.
    ///   - today: The fetch date, as `yyyy-MM-dd`.
    /// - Returns: The updated snapshot.
    /// - Throws: ``GeneratorError/brokenSource(_:)`` when the source returned no models, or lost more than a fifth of
    ///   them at once, which more likely means an outage than real removals.
    static func updated(
        source: CatalogSource,
        fetched: [CatalogModel],
        previous: CatalogSnapshot?,
        today: String
    ) throws(GeneratorError) -> CatalogSnapshot {
        guard !fetched.isEmpty else { throw .brokenSource("\(source.displayName) returned no models.") }
        let fetchedIDs = Set(fetched.map(\.id))
        let previousModels = previous?.models ?? []
        let gone = previousModels.filter { !fetchedIDs.contains($0.id) }
        guard gone.count * 5 <= previousModels.count else {
            throw .brokenSource(
                "\(source.displayName) lost \(gone.count) of \(previousModels.count) models at once; nothing was written."
            )
        }

        let stillRemoved = (previous?.removed ?? []).filter { !fetchedIDs.contains($0.model.id) }
        let newlyRemoved = gone.map { RemovedModel(model: $0, removedOn: today) }
        return CatalogSnapshot(
            source: source,
            models: fetched.sorted { $0.id < $1.id },
            removed: (stillRemoved + newlyRemoved).sorted { $0.model.id < $1.model.id }
        )
    }
}
