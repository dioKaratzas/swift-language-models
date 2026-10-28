import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

extension LiveTests {
    @Suite("Response cache")
    struct ResponseCache {
        @Test func `a repeated request is a free hit with its own id, and a refresh misses`() async throws {
            // A prompt new to this run, so the first request misses.
            let prompt = "Reply with the single word: hello. (Run \(UUID().uuidString).)"
            func answer(refreshing: Bool = false) async throws -> (entry: Transcript.Response, usage: LanguageModelSession.Usage) {
                let cache = OpenRouterResponseCache(timeToLive: .seconds(120), refreshes: refreshing)
                let model = LiveModel(.openaiGpt4_1Nano).languageModel(responseCache: cache)
                let response = try await LanguageModelSession(model: model).respond(to: prompt, options: LiveTests.short)
                record(answerMetadata(response), named: "metadata.txt")
                return (try #require(lastAnswer(in: response.transcriptEntries)), response.usage)
            }

            let miss = try await answer()
            // The cache may take a moment to keep the first answer.
            var hit = try await answer()
            var attempts = 1
            while metadataBool(hit.entry.metadata, OpenRouterMetadataKey.responseCacheHit) != true, attempts < 3 {
                try await Task.sleep(for: .seconds(2))
                hit = try await answer()
                attempts += 1
            }
            let refreshed = try await answer(refreshing: true)

            #expect(metadataBool(miss.entry.metadata, OpenRouterMetadataKey.responseCacheHit) == false)
            #expect(metadataBool(hit.entry.metadata, OpenRouterMetadataKey.responseCacheHit) == true)
            #expect((metadataNumber(hit.usage.metadata, OpenRouterMetadataKey.cost) ?? 0) < 0.000_001)
            let missID = try #require(metadataString(miss.entry.metadata, OpenRouterMetadataKey.responseID))
            #expect(metadataString(hit.entry.metadata, OpenRouterMetadataKey.responseID) != missID)
            #expect(metadataString(hit.entry.metadata, OpenRouterMetadataKey.responseCacheSourceID) == missID)
            #expect(plainText(hit.entry.segments) == plainText(miss.entry.segments))
            #expect(metadataBool(refreshed.entry.metadata, OpenRouterMetadataKey.responseCacheHit) == false)
            #expect((metadataNumber(refreshed.usage.metadata, OpenRouterMetadataKey.cost) ?? 0) > 0)
        }
    }
}
