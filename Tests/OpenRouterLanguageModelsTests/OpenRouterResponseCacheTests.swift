import Testing

@testable import OpenRouterLanguageModels

@Suite("Response cache settings")
struct OpenRouterResponseCacheTests {
    @Test func `a time to live outside OpenRouter's range is clamped to whole seconds from 1 second to 24 hours`() {
        #expect(OpenRouterResponseCache.timeToLive(clamping: .milliseconds(1_500)) == .seconds(1))
        #expect(OpenRouterResponseCache.timeToLive(clamping: .zero) == .seconds(1))
        #expect(OpenRouterResponseCache.timeToLive(clamping: .seconds(90_000)) == .seconds(86_400))
        #expect(OpenRouterResponseCache.timeToLive(clamping: .seconds(600)) == .seconds(600))
    }
}
