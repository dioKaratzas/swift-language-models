/// A set of effort words that a model accepts, as a catalog snapshot stores it.
struct CatalogEffortSet: Codable, Equatable, Sendable {
    /// Highest first.
    let words: [String]
    /// The day no model accepted the set any more, or `nil` while one does.
    let removedOn: CatalogDay?

    init(_ words: [String], removedOn: CatalogDay? = nil) {
        self.words = words
        self.removedOn = removedOn
    }

    /// The set as removed on the given day, unless it was removed earlier.
    func removed(on day: CatalogDay) -> CatalogEffortSet {
        CatalogEffortSet(words, removedOn: removedOn ?? day)
    }
}
