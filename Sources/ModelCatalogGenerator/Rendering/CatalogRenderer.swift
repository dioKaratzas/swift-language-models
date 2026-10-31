/// Turns catalog snapshots into the package's generated Swift sources.
enum CatalogRenderer {
    /// The generated files for the given snapshots.
    ///
    /// An effort word that every snapshot marks removed keeps its member, marked deprecated.
    ///
    /// - Parameter snapshots: Every snapshot in the package.
    /// - Returns: The files, in a fixed order.
    /// - Throws: ``GeneratorError/invalidCatalog(_:)`` when the snapshots can't become code.
    static func files(for snapshots: [CatalogSnapshot]) throws(GeneratorError) -> [GeneratedFile] {
        let sources = snapshots.map(\.source)
        let models = snapshots.flatMap { $0.models + $0.removed.map(\.model) }
        let ranking = try EffortRanking(
            bases: snapshots.map { $0.efforts.map(\.word) },
            lists: models.map(\.reasoningEfforts)
        )
        try SwiftIdentifier.check(
            ranking.words.map { (SwiftIdentifier.effortMember(for: $0), $0) },
            reserved: ReasoningLevelTemplate.reservedNames.union(ModelEffortsTemplate.reservedNames),
            kind: "effort words"
        )
        let removedWords = removals(in: snapshots) { snapshot in snapshot.efforts.map { ($0.word, $0.removedOn != nil) } }

        var files = [ReasoningLevelTemplate.render(ranking: ranking, removed: removedWords, sources: sources)]
        for snapshot in snapshots {
            files += try snapshot.source.vocabularies.map { (vocabulary) throws(GeneratorError) in
                try VocabularyTemplate.render(vocabulary, of: snapshot)
            }
            switch snapshot.source {
            case .openrouter: files.append(try OpenRouterModelsTemplate.render(snapshot, ranking: ranking))
            }
            files.append(try ModelEffortsTemplate.render(snapshot, ranking: ranking))
            files.append(ModelRemovalsTemplate.render(snapshot))
        }
        return files
    }

    /// The values that every snapshot tracking them marks removed, each with the first source that removed it.
    private static func removals<Value: Hashable>(
        in snapshots: [CatalogSnapshot],
        _ tracked: (CatalogSnapshot) -> [(value: Value, isRemoved: Bool)]
    ) -> [Value: CatalogSource] {
        var removals: [Value: CatalogSource] = [:]
        var current: Set<Value> = []
        for snapshot in snapshots {
            for (value, isRemoved) in tracked(snapshot) {
                if !isRemoved {
                    current.insert(value)
                } else if removals[value] == nil {
                    removals[value] = snapshot.source
                }
            }
        }
        return removals.filter { !current.contains($0.key) }
    }
}
