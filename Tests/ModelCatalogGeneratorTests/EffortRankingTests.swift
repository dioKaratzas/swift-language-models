import Testing

@testable import ModelCatalogGenerator

@Suite("Effort ranking")
struct EffortRankingTests {
    @Test func `ordered lists merge into one ranking`() throws {
        let ranking = try EffortRanking.merged([["max", "high", "low"], ["xhigh", "high", "medium", "low", "none"], ["max", "xhigh"]])

        #expect(ranking == ["max", "xhigh", "high", "medium", "low", "none"])
    }

    @Test func `words no list orders come out alphabetically`() throws {
        #expect(try EffortRanking.merged([["turbo"], ["fast"]]) == ["fast", "turbo"])
    }

    @Test func `lists that disagree fail`() {
        #expect(throws: GeneratorError.self) {
            try EffortRanking.merged([["high", "low"], ["low", "high"]])
        }
    }
}
