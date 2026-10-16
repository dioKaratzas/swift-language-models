/// The order of every effort word, merged from models that each list their own words highest first.
enum EffortRanking {
    /// Merges ordered lists into one order, highest first.
    ///
    /// Words whose order no list decides come out alphabetically, so the result never depends on input order.
    ///
    /// - Parameter lists: Effort words, each list highest first.
    /// - Returns: Every word, highest first.
    /// - Throws: ``GeneratorError/invalidCatalog(_:)`` when two lists order the same words differently.
    static func merged(_ lists: [[String]]) throws(GeneratorError) -> [String] {
        var lower: [String: Set<String>] = [:]
        var higherCount: [String: Int] = [:]
        for list in lists {
            for word in list where higherCount[word] == nil { higherCount[word] = 0 }
            for (higher, word) in zip(list, list.dropFirst()) where lower[higher, default: []].insert(word).inserted {
                higherCount[word, default: 0] += 1
            }
        }

        var ranking: [String] = []
        var ready = higherCount.filter { $0.value == 0 }.map(\.key).sorted()
        while !ready.isEmpty {
            let word = ready.removeFirst()
            ranking.append(word)
            for next in lower[word, default: []] {
                higherCount[next, default: 0] -= 1
                if higherCount[next] == 0 { ready.append(next) }
            }
            ready.sort()
        }
        guard ranking.count == higherCount.count else {
            let unordered = Set(higherCount.keys).subtracting(ranking).sorted()
            throw .invalidCatalog("Sources disagree on the order of the efforts \(unordered.joined(separator: ", ")).")
        }
        return ranking
    }
}
