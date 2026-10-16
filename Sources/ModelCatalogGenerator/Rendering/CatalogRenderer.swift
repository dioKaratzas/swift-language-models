/// Turns catalog snapshots into the package's generated Swift sources.
enum CatalogRenderer {
    /// The generated files for the given snapshots.
    ///
    /// - Parameter snapshots: Every snapshot in the package.
    /// - Returns: The files, in a fixed order.
    /// - Throws: ``GeneratorError/invalidCatalog(_:)`` when the snapshots can't become code.
    static func files(for snapshots: [CatalogSnapshot]) throws(GeneratorError) -> [GeneratedFile] {
        let sources = snapshots.map(\.source)
        let models = snapshots.flatMap { $0.models + $0.removed.map(\.model) }
        let ranking = try EffortRanking.merged(models.map(\.reasoningEfforts))
        let sets = Set(
            models.compactMap { model -> [String]? in
                guard case .set(let words) = EffortType(for: model, ranking: ranking) else { return nil }
                return words
            }
        )
        .sorted { EffortType.set(words: $0) < EffortType.set(words: $1) }

        var files = [
            ReasoningLevelTemplate.render(ranking: ranking, sources: sources),
            EffortSetsTemplate.render(sets, sources: sources),
        ]
        for snapshot in snapshots {
            switch snapshot.source {
            case .openrouter: files.append(try OpenRouterModelsTemplate.render(snapshot, ranking: ranking))
            }
        }
        return files
    }
}
