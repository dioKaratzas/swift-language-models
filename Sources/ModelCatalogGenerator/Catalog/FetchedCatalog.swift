/// What a source's documents say, in catalog form, before it joins the snapshot in the package.
struct FetchedCatalog: Sendable {
    let models: [CatalogModel]
    /// The words that the source's API description lists for each vocabulary, with their summaries.
    let vocabularies: [CatalogVocabulary: [CatalogWord]]
    /// Every effort word that the source's API description lists, highest first.
    let efforts: [String]

    /// The ids of the models.
    var modelIDs: Set<String> {
        Set(models.map(\.id))
    }
}
