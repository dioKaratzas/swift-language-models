import FoundationModels
import LanguageModels
import Testing

@Suite("Provider effort")
struct ProviderEffortTests {
    private static let ranking = ["max", "xhigh", "high", "medium", "low", "minimal", "none"]

    @Test(arguments: [
        (ContextOptions.ReasoningLevel.light, "low"),
        (.moderate, "medium"),
        (.deep, "high"),
        (.custom("max"), "max"),
    ])
    func `a level becomes the provider's word`(level: ContextOptions.ReasoningLevel, word: String) {
        let supported: [ContextOptions.ReasoningLevel] = []

        #expect(level.providerEffort(supporting: supported, ranking: Self.ranking) == word)
    }

    @Test(arguments: [
        (ContextOptions.ReasoningLevel.custom("xhigh"), ["max", "xhigh", "high"], "xhigh"),
        (.custom("max"), ["xhigh", "high", "medium", "low", "none"], "xhigh"),
        (.custom("xhigh"), ["max", "high", "medium", "low", "none"], "high"),
        (.deep, ["max", "xhigh"], "xhigh"),
        (.light, ["high"], "high"),
        (.custom("none"), ["medium", "low"], "low"),
    ])
    func `a level moves to the nearest level the model accepts`(
        level: ContextOptions.ReasoningLevel,
        supported: [String],
        word: String
    ) {
        let supported = supported.map(ContextOptions.ReasoningLevel.custom)

        #expect(level.providerEffort(supporting: supported, ranking: Self.ranking) == word)
    }

    @Test func `a word new to the ranking takes its place in it`() {
        let supported: [ContextOptions.ReasoningLevel] = [.custom("max"), .custom("high")]

        #expect(
            ContextOptions.ReasoningLevel.custom("ultra").providerEffort(supporting: supported, ranking: ["ultra"] + Self.ranking)
                == "max"
        )
    }

    @Test func `a word missing from the ranking is left out for a model that lists its levels`() {
        let supported: [ContextOptions.ReasoningLevel] = [.custom("high"), .custom("low")]

        #expect(ContextOptions.ReasoningLevel.custom("ultra").providerEffort(supporting: supported, ranking: Self.ranking) == nil)
    }

    @Test func `any word is sent unchanged to a model that lists no levels`() {
        let supported: [ContextOptions.ReasoningLevel] = []

        #expect(ContextOptions.ReasoningLevel.custom("ultra").providerEffort(supporting: supported, ranking: Self.ranking) == "ultra")
    }
}
