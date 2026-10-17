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
        let sets = Set(models.map { EffortType(for: $0, ranking: ranking).words }.filter { !$0.isEmpty })
            .sorted { EffortType.set(words: $0) < EffortType.set(words: $1) }

        var files = [
            ReasoningLevelTemplate.render(ranking: ranking, sources: sources),
            EffortSetsTemplate.render(sets, sources: sources),
        ]
        for snapshot in snapshots {
            for vocabulary in CatalogVocabulary.allCases {
                files.append(try VocabularyTemplate.render(vocabulary, of: snapshot))
            }
            switch snapshot.source {
            case .openrouter: files.append(try OpenRouterModelsTemplate.render(snapshot, ranking: ranking))
            }
        }
        return files
    }
}
