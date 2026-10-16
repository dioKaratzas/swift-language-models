package import FoundationModels

extension ContextOptions.ReasoningLevel {
    /// The word to send for this level to a model that accepts the given levels.
    ///
    /// `light`, `moderate` and `deep` ask for `low`, `medium` and `high`; a custom level asks for its own word. A level
    /// the model accepts is sent as is. Otherwise the nearest accepted level in `ranking` is sent, the lower one on a
    /// tie. When the model lists no levels, the word is sent unchanged. A word missing from `ranking`, on a model that
    /// lists its levels, gives `nil`, so the provider uses its default.
    ///
    /// - Parameters:
    ///   - supported: The levels the model accepts.
    ///   - ranking: Every known effort word, highest first.
    /// - Returns: The provider's word for the level, or `nil` to leave it out of the request.
    package func providerEffort(supporting supported: [some ModelEffort], ranking: [String]) -> String? {
        guard let word else { return nil }
        let supportedWords = supported.compactMap(\.reasoningLevel.word)
        guard !supportedWords.isEmpty, !supportedWords.contains(word) else { return word }
        guard let position = ranking.firstIndex(of: word) else { return nil }

        let ranked = supportedWords.compactMap { candidate in
            ranking.firstIndex(of: candidate).map { (word: candidate, position: $0) }
        }
        return ranked.min { lhs, rhs in
            let (lhsDistance, rhsDistance) = (abs(lhs.position - position), abs(rhs.position - position))
            return lhsDistance == rhsDistance ? lhs.position > rhs.position : lhsDistance < rhsDistance
        }?.word
    }

    private var word: String? {
        switch self {
        case .light: "low"
        case .moderate: "medium"
        case .deep: "high"
        case .custom(let word): word
        @unknown default: nil
        }
    }
}
