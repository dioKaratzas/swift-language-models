import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

extension LiveTests {
    @Suite("Routing")
    struct Routing {
        @Test func `a prompt too long for the model is answered by its fallback`() async throws {
            let key = APIKey.current ?? ""
            let model = OpenRouterLanguageModel(
                .microsoftPhi4,
                fallbacks: .mistralaiMistralNemo,
                options: OpenRouterOptions(includesRouterMetadata: true),
                app: OpenRouterApp(name: liveAppName),
                apiKey: { key }
            )
            // About 17,000 tokens, past phi-4's 16,384.
            let prompt = String(repeating: "word ", count: 17_000) + "\nReply with OK."

            let response = try await LanguageModelSession(model: model).respond(to: prompt, options: LiveTests.short)

            let answer = try #require(lastAnswer(in: response.transcriptEntries))
            record(answer.metadata, named: "metadata.txt")
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.model)?.hasPrefix("mistralai/mistral-nemo") == true)
            #expect(response.usage.input.totalTokenCount > 16_384)
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.routingStrategy) != nil)
        }

        /// With one attempt, the report has no list of attempts.
        @Test func `router metadata on a fallback chain reports the strategy, the endpoints, the region and the time`() async throws {
            let model = LiveModel(.openaiGpt4_1Nano).languageModel(
                fallbacks: [LiveModel(.mistralaiMistralNemo).details],
                options: OpenRouterOptions(includesRouterMetadata: true)
            )

            let response = try await LanguageModelSession(model: model).respond(
                to: "Reply with the single word: hello",
                options: LiveTests.short
            )

            let answer = try #require(lastAnswer(in: response.transcriptEntries))
            record(answer.metadata, named: "metadata.txt")
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.routingStrategy) == "fallback")
            #expect((metadataNumber(answer.metadata, OpenRouterMetadataKey.routingAttempt) ?? 0) >= 1)
            let endpoints = elements(try metadataJSON(answer.metadata, OpenRouterMetadataKey.routingEndpoints))
            #expect(endpoints.count >= 2, "Expected the endpoints of both models: \(endpoints)")
            #expect(endpoints.allSatisfy { $0["provider"]?.stringValue != nil && $0["model"]?.stringValue != nil })
            #expect(endpoints.filter { $0["selected"] == true }.count == 1)
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.region)?.isEmpty == false)
            #expect((metadataNumber(answer.metadata, OpenRouterMetadataKey.generationTime) ?? 0) > 0)
        }

        @Test func `a pinned host serves the answer`() async throws {
            let session = LanguageModelSession(model: LiveModel(.mistralaiMistralNemo).languageModel(routing: LiveTests.mistralHost))

            let response = try await session.respond(to: "Reply with the single word: hello", options: LiveTests.short)

            let answer = try #require(lastAnswer(in: response.transcriptEntries))
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.provider) == "Mistral")
        }

        @Test func `a pinned host that doesn't serve the model throws OpenRouter's error`() async throws {
            let routing = OpenRouterRouting(order: ["Anthropic"], allowsFallbacks: false)
            let session = LanguageModelSession(model: LiveModel(.mistralaiMistralNemo).languageModel(routing: routing))

            let error = try await #require(throws: OpenRouterError.self) {
                try await session.respond(to: "Reply with the single word: hello", options: LiveTests.short)
            }

            record(error, named: "error.txt")
            #expect([404, 503].contains(error.status))
        }

        /// The router picks from its own pool, which changes with usage, so the test allows whole vendors by pattern
        /// rather than single models that may leave the pool.
        @Test func `the auto router answers with one of the allowed models`() async throws {
            let allowed = ["openai/*", "google/*"]
            let options = OpenRouterOptions(autoRouter: OpenRouterAutoRouter(allowedModels: allowed))
            let session = LanguageModelSession(model: LiveModel(.openrouterAuto).languageModel(options: options))

            let response = try await session.respond(to: "Reply with the single word: hello", options: LiveTests.short)

            record(answerMetadata(response), named: "metadata.txt")
            let answer = try #require(lastAnswer(in: response.transcriptEntries))
            let answering = try #require(metadataString(answer.metadata, OpenRouterMetadataKey.model))
            #expect(allowed.contains { answering.hasPrefix($0.dropLast()) })
            #expect((metadataNumber(response.usage.metadata, OpenRouterMetadataKey.cost) ?? 0) > 0)
        }

        @Test func `an alias answers with a model of its vendor`() async throws {
            let session = LanguageModelSession(model: LiveModel(.deepseekDeepseekFlashLatest).languageModel)

            let response = try await session.respond(
                to: "Reply with the single word: hello",
                options: LiveTests.short,
                contextOptions: ContextOptions(reasoningLevel: .off)
            )

            let answer = try #require(lastAnswer(in: response.transcriptEntries))
            record(answer.metadata, named: "metadata.txt")
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.model)?.hasPrefix("deepseek/") == true)
        }

        @Test(arguments: [OpenRouterRouting.Variant.nitro, .floor])
        func `a variant still reports the model and the host that served it`(variant: OpenRouterRouting.Variant) async throws {
            let model = LiveModel(.metaLlamaLlama3_1_8bInstruct).languageModel(routing: OpenRouterRouting(variant: variant))

            let response = try await LanguageModelSession(model: model).respond(
                to: "Reply with the single word: hello",
                options: LiveTests.short
            )

            let answer = try #require(lastAnswer(in: response.transcriptEntries))
            record(answer.metadata, named: "metadata.txt")
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.model)?.hasPrefix("meta-llama/llama-3.1-8b-instruct") == true)
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.provider) != nil)
        }
    }
}
