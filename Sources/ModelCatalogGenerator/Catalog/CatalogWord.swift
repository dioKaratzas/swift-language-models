/// A word of an open vocabulary, as a catalog snapshot stores it.
struct CatalogWord: Codable, Equatable, Sendable {
    let word: String
    /// What the word means, from the source's API description.
    let summary: String?
    /// The day the word disappeared from its source, as `yyyy-MM-dd`, or `nil` while the source uses it.
    let removedOn: String?

    init(_ word: String, summary: String? = nil, removedOn: String? = nil) {
        self.word = word
        self.summary = summary
        self.removedOn = removedOn
    }

    /// The word as removed on the given day, unless it was removed earlier.
    func removed(on day: String) -> CatalogWord {
        CatalogWord(word, summary: summary, removedOn: removedOn ?? day)
    }
}
