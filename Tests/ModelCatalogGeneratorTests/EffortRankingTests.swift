import Testing

@testable import ModelCatalogGenerator

@Suite("Effort ranking")
struct EffortRankingTests {
    @Test func `ordered lists merge into one ranking`() throws {
        let ranking = try EffortRanking(
            bases: [], lists: [["max", "high", "low"], ["xhigh", "high", "medium", "low", "none"], ["max", "xhigh"]])

        #expect(ranking.words == ["max", "xhigh", "high", "medium", "low", "none"])
    }

    @Test func `words no list orders come out alphabetically`() throws {
        #expect(try EffortRanking(bases: [], lists: [["turbo"], ["fast"]]).words == ["fast", "turbo"])
    }

    @Test func `lists that disagree fail`() {
        #expect(throws: GeneratorError.invalidCatalog("Sources disagree on the order of the efforts high, low.")) {
            try EffortRanking(bases: [], lists: [["high", "low"], ["low", "high"]])
        }
    }

    @Test func `the base decides the order of its own words`() throws {
        let ranking = try EffortRanking(bases: [["high", "medium", "low"]], lists: [["low", "high"], ["medium", "high"]])

        #expect(ranking.words == ["high", "medium", "low"])
    }

    @Test func `the other lists place the words the base doesn't have`() throws {
        let ranking = try EffortRanking(
            bases: [["high", "low"]], lists: [["max", "high"], ["low", "none"], ["high", "middling", "low"]])

        #expect(ranking.words == ["max", "high", "middling", "low", "none"])
    }

    @Test func `bases that disagree fail`() {
        #expect(throws: GeneratorError.self) {
            try EffortRanking(bases: [["high", "low"], ["low", "high"]])
        }
    }

    @Test func `a word listed twice in a row is ordered once`() throws {
        #expect(try EffortRanking(bases: [], lists: [["high", "high", "low"]]).words == ["high", "low"])
    }

    @Test func `words come out in the ranking's order, each once`() throws {
        let ranking = try EffortRanking(bases: [["max", "high", "low"]])

        #expect(ranking.sorted(["low", "max", "low", "unknown"]) == ["max", "low"])
    }
}
