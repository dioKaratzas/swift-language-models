/// A source's models as `Catalogs/<source>.json` stores them, sorted so the file's diff reads as a changelog.
struct CatalogSnapshot: Codable, Equatable, Sendable {
    let source: CatalogSource
    let models: [CatalogModel]
    let removed: [RemovedModel]
    /// Every word of each vocabulary, sorted, including the words the source no longer uses.
    let vocabularies: [CatalogVocabulary: [CatalogWord]]
    /// Every effort word, highest first, including the words the source no longer uses.
    let efforts: [CatalogWord]
    /// Every set of efforts that a model accepts, sorted, including the sets no model accepts any more.
    let effortSets: [CatalogEffortSet]

    /// The snapshot after a fetch: new and changed models replace old ones, and missing models move to `removed`.
    ///
    /// Each vocabulary, and the efforts, hold the words the source lists and the words its models use. A word that's
    /// in neither any more stays, marked removed, and so does an effort set that neither a model nor a removed model
    /// accepts any more. The source's own order of efforts decides the order of its words; the models' lists place
    /// the others.
    ///
    /// - Parameters:
    ///   - source: The source the models came from.
    ///   - fetched: The models and words the source returned.
    ///   - previous: The snapshot in the package, if any.
    ///   - today: The fetch date, as `yyyy-MM-dd`.
    /// - Returns: The updated snapshot.
    /// - Throws: ``GeneratorError/brokenSource(_:)`` when the source returned no models, listed a model twice or a
    ///   model that doesn't output text, or lost more than a fifth of its models at once, which more likely means an
    ///   outage than real removals. ``GeneratorError/invalidCatalog(_:)`` when the efforts can't be put in one order.
    static func updated(
        source: CatalogSource,
        fetched: FetchedCatalog,
        previous: CatalogSnapshot?,
        today: String
    ) throws(GeneratorError) -> CatalogSnapshot {
        guard !fetched.models.isEmpty else { throw .brokenSource("\(source.displayName) returned no models.") }
        let repeated = Dictionary(grouping: fetched.models, by: \.id).filter { $0.value.count > 1 }.keys.sorted()
        guard repeated.isEmpty else {
            throw .brokenSource("\(source.displayName) listed these models more than once: \(repeated.joined(separator: ", ")).")
        }
        let textless = fetched.models.filter { !$0.outputModalities.contains("text") }.map(\.id).sorted()
        guard textless.isEmpty else {
            throw .brokenSource("\(source.displayName) listed models that don't output text: \(textless.joined(separator: ", ")).")
        }
        let fetchedIDs = Set(fetched.models.map(\.id))
        let previousModels = previous?.models ?? []
        let gone = previousModels.filter { !fetchedIDs.contains($0.id) }
        guard gone.count * 5 <= previousModels.count else {
            throw .brokenSource(
                "\(source.displayName) lost \(gone.count) of \(previousModels.count) models at once; nothing was written."
            )
        }

        let stillRemoved = (previous?.removed ?? []).filter { !fetchedIDs.contains($0.model.id) }
        let newlyRemoved = gone.map { RemovedModel(model: $0, removedOn: today) }
        let removed = (stillRemoved + newlyRemoved).sorted { $0.model.id < $1.model.id }
        let models = fetched.models + removed.map(\.model)
        let ranking = try EffortRanking(
            bases: [fetched.efforts],
            lists: models.map(\.reasoningEfforts) + (previous?.effortSets ?? []).map(\.words) + [(previous?.efforts ?? []).map(\.word)]
        )
        return CatalogSnapshot(
            source: source,
            models: fetched.models.sorted { $0.id < $1.id },
            removed: removed,
            vocabularies: Dictionary(
                uniqueKeysWithValues: CatalogVocabulary.allCases.map { vocabulary in
                    (
                        vocabulary,
                        words(
                            listed: fetched.vocabularies[vocabulary] ?? [],
                            used: fetched.models.flatMap(vocabulary.words(of:)),
                            previous: previous?.vocabularies[vocabulary] ?? [],
                            today: today
                        ).sorted { $0.word < $1.word }
                    )
                }
            ),
            efforts: efforts(in: fetched, ranking: ranking, previous: previous, today: today),
            effortSets: effortSets(of: models, ranking: ranking, previous: previous, today: today)
        )
    }

    /// The effort words, in the ranking's order.
    private static func efforts(
        in fetched: FetchedCatalog,
        ranking: EffortRanking,
        previous: CatalogSnapshot?,
        today: String
    ) -> [CatalogWord] {
        let efforts = words(
            listed: fetched.efforts.map { CatalogWord($0) },
            used: fetched.models.flatMap(\.reasoningEfforts),
            previous: previous?.efforts ?? [],
            today: today
        )
        let effortsByWord = Dictionary(efforts.map { ($0.word, $0) }) { first, _ in first }
        return ranking.words.compactMap { effortsByWord[$0] }
    }

    /// The effort sets that the models accept, then the earlier snapshot's sets that none accepts any more, marked
    /// removed, sorted.
    private static func effortSets(
        of models: [CatalogModel],
        ranking: EffortRanking,
        previous: CatalogSnapshot?,
        today: String
    ) -> [CatalogEffortSet] {
        let used = Set(models.map { ranking.sorted($0.reasoningEfforts) }.filter { !$0.isEmpty })
        let gone = (previous?.effortSets ?? []).map { CatalogEffortSet(ranking.sorted($0.words), removedOn: $0.removedOn) }
            .filter { !used.contains($0.words) }
            .map { $0.removed(on: today) }
        return (used.map { CatalogEffortSet($0) } + gone).sorted { $0.words.lexicographicallyPrecedes($1.words) }
    }

    /// The words a source lists, then the other words its models use, then the words of an earlier snapshot that are
    /// in neither any more, marked removed.
    private static func words(listed: [CatalogWord], used: [String], previous: [CatalogWord], today: String) -> [CatalogWord] {
        let listedWords = Set(listed.map(\.word))
        let unlisted = Set(used).subtracting(listedWords).sorted().map { CatalogWord($0) }
        let current = listedWords.union(used)
        let gone = previous.filter { !current.contains($0.word) }.map { $0.removed(on: today) }
        return listed + unlisted + gone
    }
}
