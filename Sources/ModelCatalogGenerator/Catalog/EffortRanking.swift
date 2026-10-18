/// The order of every effort word, highest first, merged from lists that each order some of the words.
struct EffortRanking: Equatable {
    /// Every word, highest first.
    let words: [String]

    /// Merges ordered lists into one order, highest first.
    ///
    /// The base lists, such as a source's own list of efforts, decide the order of their words. The other lists, such
    /// as each model's efforts, only place the words that no base list has, so a model that lists two known words
    /// out of order changes nothing. Words whose order nothing decides come out alphabetically, so the result never
    /// depends on input order.
    ///
    /// - Parameters:
    ///   - bases: Lists that decide the order of their words, each highest first.
    ///   - lists: Lists that place the other words, each highest first.
    /// - Throws: ``GeneratorError/invalidCatalog(_:)`` when the lists order the same words differently.
    init(bases: [[String]], lists: [[String]] = []) throws(GeneratorError) {
        let known = Set(bases.joined())
        var lower: [String: Set<String>] = [:]
        var higherCount: [String: Int] = [:]
        func add(_ list: [String], ordersKnownWords: Bool) {
            for word in list where higherCount[word] == nil { higherCount[word] = 0 }
            for (higher, word) in zip(list, list.dropFirst())
            where higher != word && (ordersKnownWords || !known.isSuperset(of: [higher, word]))
                && lower[higher, default: []].insert(word).inserted
            {
                higherCount[word, default: 0] += 1
            }
        }
        for base in bases { add(base, ordersKnownWords: true) }
        for list in lists { add(list, ordersKnownWords: false) }

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
        words = ranking
    }

    /// The given words in the ranking's order, leaving out repeats and words the ranking doesn't have.
    func sorted(_ words: [String]) -> [String] {
        let members = Set(words)
        return self.words.filter(members.contains)
    }
}
