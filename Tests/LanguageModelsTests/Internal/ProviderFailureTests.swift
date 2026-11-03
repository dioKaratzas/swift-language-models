import FoundationModels
import LanguageModels
import Testing

@Suite("Provider failure")
struct ProviderFailureTests {
    @Test(
        arguments: [
            ("This model's maximum context length is 128000 tokens. However, your messages resulted in 130000 tokens.", 128_000, 130_000),
            ("maximum context length is 200000 tokens. However, you requested about 250000 tokens", 200_000, 250_000),
            ("Your input exceeds the context window of 400000 tokens.", 400_000, nil),
            ("Your input exceeds the context window of this model.", nil, nil),
        ] as [(String, Int?, Int?)])
    func `an oversized prompt's message names the context size and the tokens it needs, when it does`(
        message: String, limit: Int?, requested: Int?
    ) {
        let sizes = LanguageModelError.ProviderFailure.contextSizes(in: message)

        #expect(sizes.limit == limit)
        #expect(sizes.requested == requested)
    }
}
