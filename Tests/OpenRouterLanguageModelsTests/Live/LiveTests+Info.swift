import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

extension LiveTests {
    @Suite("Model info")
    struct Info {
        /// OpenRouter reports latency and throughput only to a call with a key. A first token takes from 10 ms to two
        /// minutes, and a host generates from 1 to 5,000 tokens a second, so a value read in the wrong unit falls out.
        @Test func `with the key, providers report latency in milliseconds and throughput in tokens per second`() async throws {
            let providers = try await LiveModel(.anthropicClaudeHaiku5_5).languageModel.providers()

            let latencies = providers.compactMap(\.latencyLast30Minutes?.p50)
            let throughputs = providers.compactMap(\.throughputLast30Minutes?.p50)
            try #require(!latencies.isEmpty, "No endpoint reported its latency")
            #expect(latencies.allSatisfy { $0 > .milliseconds(10) && $0 < .seconds(120) }, "\(latencies)")
            #expect(throughputs.allSatisfy { (1...5_000).contains($0) }, "\(throughputs)")
        }

        @Test func `with the key, current details read as without it`() async throws {
            let details = try await LiveModel(.anthropicClaudeHaiku5_5).languageModel.currentDetails()

            #expect(details.id == "anthropic/claude-haiku-5.5")
            #expect((details.pricing?.completion ?? 0) > 0)
        }
    }
}
