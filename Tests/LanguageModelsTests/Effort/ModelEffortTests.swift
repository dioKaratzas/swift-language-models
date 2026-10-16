import FoundationModels
import LanguageModels
import Testing

@Suite("Model effort")
struct ModelEffortTests {
    @Test(arguments: [ContextOptions.ReasoningLevel.light, .deep, .custom("max")])
    func `a reasoning level is its own effort`(level: ContextOptions.ReasoningLevel) {
        #expect(level.reasoningLevel == level)
    }

    @Test(arguments: [HighLowEffort.high, .low])
    func `a typed effort asks for the custom level named after it`(effort: HighLowEffort) {
        #expect(effort.reasoningLevel == .custom(effort.rawValue))
    }
}
