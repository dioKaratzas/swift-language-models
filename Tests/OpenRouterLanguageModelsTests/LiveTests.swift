import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

/// Requests to real models through OpenRouter, for what only a provider can show: which schemas it accepts, how it
/// caches, what it needs replayed and how it fails. A full run costs about three cents.
///
/// The executor risks suite probes the ways the executor may break on some models, each named after its risk. A probe
/// that fails today runs in a known issue, so it reports once the risk is fixed; the others guard what works, whether
/// the executor or OpenRouter handles it.
@Suite(
    "Live: OpenRouter",
    .tags(.live),
    .requiresAPIKey("OPENROUTER_API_KEY"),
    .skipsUnavailableHosts,
    .timeLimit(.minutes(2))
)
struct LiveTests {
    /// A response limit for answers of a few words.
    static let short = GenerationOptions(maximumResponseTokens: 16)

    /// Mistral's own host, which takes only 9-character tool-call ids. It charges a regional surcharge, so OpenRouter's
    /// default routing skips it for a model that other hosts serve, unless a request pins its regional slug.
    static let mistralHost = OpenRouterRouting(order: ["mistral/eu"], allowsFallbacks: false)

    @Suite("Text")
    struct Text {
        @Test func `a cheap model answers with its usage, cost and host`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            let response = try await session.respond(to: "Reply with the single word: hello", options: LiveTests.short)

            record(response, named: "response.txt")
            #expect(response.content.localizedCaseInsensitiveContains("hello"))
            #expect(response.usage.input.totalTokenCount > 0)
            #expect(response.usage.output.totalTokenCount > 0)
            #expect((metadataNumber(response.usage.metadata, OpenRouterMetadataKey.cost) ?? 0) > 0)
            let answer = try #require(lastAnswer(in: response.transcriptEntries))
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.model)?.hasPrefix("openai/gpt-4.1-nano") == true)
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.provider) != nil)
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.responseID)?.hasPrefix("gen-") == true)
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.finishReason) == "stop")
        }

        @Test func `a streamed answer grows with each snapshot`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            var snapshots: [String] = []
            let stream = session.streamResponse(
                to: "Count from 1 to 10, separated by spaces.",
                options: GenerationOptions(maximumResponseTokens: 64)
            )
            for try await snapshot in stream {
                snapshots.append(snapshot.content)
            }

            let answer = try #require(snapshots.last)
            #expect(answer.contains("10"))
            #expect(snapshots.allSatisfy { answer.hasPrefix($0) })
        }

        @Test func `a session remembers its earlier turns`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            _ = try await session.respond(to: "My favorite color is teal. Reply with OK.", options: LiveTests.short)
            let response = try await session.respond(to: "What is my favorite color? Reply with one word.", options: LiveTests.short)

            #expect(response.content.localizedCaseInsensitiveContains("teal"))
        }

        @Test func `an answer cut short by the token limit keeps its text`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            let response = try await session.respond(to: "Count from 1 to 200, separated by spaces.", options: LiveTests.short)

            #expect(!response.content.isEmpty)
            #expect(response.usage.output.totalTokenCount <= 16)
            let answer = try #require(lastAnswer(in: response.transcriptEntries))
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.finishReason) == "length")
        }

        /// Foundation Models ends a cancelled stream without throwing, so only the stop and the next answer count.
        @Test func `a cancelled stream stops at once and the session answers again`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)
            let (snapshots, snapshotArrived) = AsyncStream.makeStream(of: Void.self)

            let streaming = Task {
                defer { snapshotArrived.finish() }
                let stream = session.streamResponse(
                    to: "Count from 1 to 300, separated by spaces.",
                    options: GenerationOptions(maximumResponseTokens: 1_000)
                )
                for try await _ in stream {
                    snapshotArrived.yield()
                }
            }
            var count = 0
            for await _ in snapshots {
                count += 1
                if count == 3 { break }
            }
            let cancelledAt = ContinuousClock.now
            streaming.cancel()
            let result = await streaming.result
            let wait = ContinuousClock.now - cancelledAt

            record(wait, named: "wait.txt")
            if case .failure(let error) = result, !(error is CancellationError) { throw error }
            #expect(count == 3)
            #expect(wait < .seconds(2))
            let again = try await session.respond(to: "Reply with the single word: done", options: LiveTests.short)
            #expect(again.content.localizedCaseInsensitiveContains("done"))
        }

        @Test func `a low verbosity gives a shorter answer than a high one`() async throws {
            func answer(_ verbosity: OpenRouterVerbosity) async throws -> String {
                let model = LiveModel(.openaiGpt5Nano).languageModel(options: OpenRouterOptions(verbosity: verbosity))
                let response = try await LanguageModelSession(model: model).respond(
                    to: "Why is the sky blue?",
                    options: GenerationOptions(maximumResponseTokens: 4_000),
                    contextOptions: ContextOptions(reasoningLevel: .minimal)
                )
                record(response.content, named: "\(verbosity.rawValue).txt")
                let entry = try #require(lastAnswer(in: response.transcriptEntries))
                #expect(metadataString(entry.metadata, OpenRouterMetadataKey.finishReason) == "stop")
                return response.content
            }

            let low = try await answer(.low)
            let high = try await answer(.high)

            // Verbosity is a hint, so the high answer only has to be clearly longer.
            #expect(Double(high.count) >= 1.5 * Double(low.count))
        }
    }

    @Suite("Guided generation")
    struct GuidedGeneration {
        /// Models with strict structured outputs, and one with only JSON mode. The Anthropic alias shows that a schema
        /// written for Anthropic also goes to a model named through `~`.
        static let models = [
            LiveModel(.openaiGpt4_1Nano),
            LiveModel(.anthropicClaudeHaiku5_5),
            LiveModel(.anthropicClaudeHaikuLatest),
            LiveModel(.googleGemini2_5FlashLite),
            LiveModel(.deepseekDeepseekV4Flash),
            LiveModel(.qwenQwen3_7Flash),
        ]

        @Test(arguments: models)
        func `the provider accepts the schema and its answer decodes`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel)

            let trip = try await session.respond(to: "Plan a short trip to Lisbon.", generating: Trip.self).content

            record(trip, named: "trip.txt")
            #expect(trip.activities.count == 3)
            #expect((1...14).contains(trip.days))
            #expect(trip.activities.allSatisfy { (1...12).contains($0.hours) })
        }

        @Test func `a streamed list of forty items grows to all of them`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            var counts: [Int] = []
            var last: GeneratedContent?
            let stream = session.streamResponse(to: "List forty things to pack for a week of hiking.", generating: PackingList.self)
            for try await snapshot in stream {
                counts.append(snapshot.content.items?.count ?? 0)
                last = snapshot.rawContent
            }
            let list = try PackingList(try #require(last))

            record(list.items, named: "items.txt")
            #expect(list.items.count == 40)
            #expect(counts.count > 1)
            #expect(counts == counts.sorted())
        }
    }

    @Suite("Tools")
    struct Tools {
        /// Models that call tools in parallel. Gemini can send parallel calls that share an index or an id.
        static let parallelModels = [LiveModel(.openaiGpt4_1Nano), LiveModel(.googleGemini2_5FlashLite)]

        /// Models that may leave out the arguments of a tool without parameters, or reject its empty schema.
        static let noArgumentModels = [LiveModel(.googleGemini2_5FlashLite), LiveModel(.anthropicClaudeHaiku4_5)]

        /// Also probes risk 4: calls that share an index would merge into one call with both arguments.
        @Test(arguments: parallelModels)
        func `calls for three cities get one call each with its own id`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel, tools: [WeatherTool()])

            let response = try await session.respond(
                to: "How warm is it in Lisbon, Porto and Madrid right now? Use the tool once for each city."
            )

            record(session.transcript, named: "transcript.txt")
            // A model may call the tool one city at a time, so the calls are counted across rounds.
            let calls = session.transcript.toolCalls
            #expect(Set(calls.map(\.id)).count == calls.count)
            let cities = try session.transcript.weatherCities()
            for city in ["Lisbon", "Porto", "Madrid"] {
                #expect(cities.contains { $0.localizedCaseInsensitiveContains(city) }, "No call for \(city)")
            }
            #expect(response.content.contains("17"))
        }

        @Test(arguments: noArgumentModels)
        func `a tool without arguments runs and its answer reaches the reply`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel, tools: [AccessCodeTool()])

            let response = try await session.respond(to: "What is today's access code? Use the tool.")

            record(session.transcript, named: "transcript.txt")
            #expect(session.transcript.toolCalls.contains { $0.toolName == "getAccessCode" })
            #expect(response.content.contains("K7Q2"))
        }

        /// The backslash sits inside the text, since a model tends to mangle a trailing one.
        @Test func `tool arguments keep their Unicode and escapes, and the stream ends with the answer`() async throws {
            let text = #"Grüße 👋🏽 日本語 "q" \ 🇵🇹 end"#
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel, tools: [EchoTool()])

            var snapshots: [String] = []
            let stream = session.streamResponse(
                to: "Call the echo tool once with exactly this text, then reply with what it returned: \(text)"
            )
            for try await snapshot in stream {
                snapshots.append(snapshot.content)
            }

            record(session.transcript, named: "transcript.txt")
            let call = try #require(session.transcript.toolCalls.first { $0.toolName == "echo" })
            let echoed = try call.arguments.value(String.self, forProperty: "text")
            #expect(echoed.precomposedStringWithCanonicalMapping == text.precomposedStringWithCanonicalMapping)
            // Each round of a tool loop streams anew, so only the last snapshot has to be the answer.
            let answer = try #require(lastAnswer(in: session.transcript))
            #expect(snapshots.last == plainText(answer.segments))
        }

        @Test func `a required tool call comes even for a prompt that needs none`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel, tools: [InterruptingWeatherTool()])

            let response = try await respondUntilToolCall(session, to: "Say hello.", options: GenerationOptions(toolCallingMode: .required))

            record(session.transcript, named: "transcript.txt")
            #expect(response == nil, "The model answered without calling the tool: \(response?.content ?? "")")
            #expect(session.transcript.toolCalls.contains { $0.toolName == "getWeather" })
        }
    }

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

    @Suite("Server tools")
    struct ServerTools {
        @Test func `a web search answer cites https pages and counts the search`() async throws {
            let search = OpenRouterServerTool.webSearch(engine: .parallel, maximumResults: 3, maximumSearches: 1)
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel(serverTools: [search]))

            let response = try await session.respond(
                to: "Search the web for the official website of the Swift programming language, and name it."
            )

            record(answerMetadata(response), named: "metadata.txt")
            let citations = try #require(lastAnswer(in: response.transcriptEntries)).openRouterCitations
            #expect(!citations.isEmpty)
            // A search engine may cite a page that's only served over http.
            #expect(citations.allSatisfy { ["http", "https"].contains($0.url.scheme) })
            let usage = response.usage.metadata
            #expect(
                metadataNumber(usage, OpenRouterMetadataKey.webSearchCount) != nil
                    || metadataNumber(usage, OpenRouterMetadataKey.serverToolCost) != nil
            )
        }

        @Test func `a fetched page reaches the answer`() async throws {
            let fetch = OpenRouterServerTool.webFetch(engine: .openrouter, maximumFetches: 1)
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel(serverTools: [fetch]))

            let response = try await session.respond(to: "Fetch https://example.com and reply with the page's title.")

            record(answerMetadata(response), named: "metadata.txt")
            #expect(response.content.contains("Example Domain"))
            #expect((metadataNumber(response.usage.metadata, OpenRouterMetadataKey.requestedServerToolCallCount) ?? 0) >= 1)
        }

        @Test func `the date tool gives the current year`() async throws {
            let datetime = OpenRouterServerTool.datetime(timeZone: .gmt)
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel(serverTools: [datetime]))

            let response = try await session.respond(to: "What is today's date? Use the tool, and reply with the date only.")

            record(answerMetadata(response), named: "metadata.txt")
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .gmt
            #expect(response.content.contains(String(calendar.component(.year, from: .now))))
        }

        @Test func `the advisor answers, and the usage counts the consultation`() async throws {
            let advisor = OpenRouterServerTool.advisor(model: OpenRouterModel.openaiGpt4_1Nano.id, maximumResponseTokens: 100)
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel(serverTools: [advisor]))

            let response = try await session.respond(
                to: "Ask the advisor whether 17 × 23 is 391, then reply with its verdict in one sentence.",
                options: GenerationOptions(maximumResponseTokens: 200)
            )

            record(answerMetadata(response), named: "metadata.txt")
            record(session.transcript, named: "transcript.txt")
            #expect(!response.content.isEmpty)
            #expect((metadataNumber(response.usage.metadata, OpenRouterMetadataKey.requestedServerToolCallCount) ?? 0) >= 1)
            #expect(session.transcript.toolCalls.isEmpty)
        }

        @Test func `the subagent's outcome reaches the answer, and the usage counts the task`() async throws {
            let subagent = OpenRouterServerTool.subagent(model: OpenRouterModel.openaiGpt4_1Nano.id, maximumResponseTokens: 100)
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel(serverTools: [subagent]))

            let response = try await session.respond(
                to: "Delegate this task to the subagent: write the word 'harbor' in capital letters. Then reply with its outcome only.",
                options: GenerationOptions(maximumResponseTokens: 200)
            )

            record(answerMetadata(response), named: "metadata.txt")
            record(session.transcript, named: "transcript.txt")
            #expect(response.content.contains("HARBOR"))
            #expect((metadataNumber(response.usage.metadata, OpenRouterMetadataKey.requestedServerToolCallCount) ?? 0) >= 1)
            #expect(session.transcript.toolCalls.isEmpty)
        }

        @Test func `a required tool call is met with an app tool and a server tool on offer`() async throws {
            let model = LiveModel(.openaiGpt4_1Nano).languageModel(serverTools: [.datetime(timeZone: .gmt)])
            let session = LanguageModelSession(model: model, tools: [InterruptingWeatherTool()])

            let response = try await respondUntilToolCall(
                session,
                to: "How warm is it in Lisbon today, and what is the date?",
                options: GenerationOptions(toolCallingMode: .required)
            )

            record(session.transcript, named: "transcript.txt")
            if let response {
                // A server tool's call can meet the requirement on its own.
                record(answerMetadata(response), named: "metadata.txt")
                #expect((metadataNumber(response.usage.metadata, OpenRouterMetadataKey.requestedServerToolCallCount) ?? 0) >= 1)
            } else {
                #expect(session.transcript.toolCalls.contains { $0.toolName == "getWeather" })
            }
        }
    }

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

    @Suite("Caching")
    struct Caching {
        /// Models that cache on their own or with markers, but don't promise a hit.
        static let bestEffortModels = [
            LiveModel(.openaiGpt4_1Nano),
            LiveModel(.googleGemini2_5FlashLite, cacheControl: .ephemeral),
            LiveModel(.deepseekDeepseekV4Flash),
            LiveModel(.qwenQwen3_7Flash, cacheControl: .ephemeral),
        ]

        /// Each of Claude's hosts keeps its own cache, so both turns go to Anthropic's own host.
        @Test func `a marked prompt is written on the first turn and read on the next`() async throws {
            let model = LiveModel(.anthropicClaudeHaiku5_5, cacheControl: .ephemeral)
            let routing = OpenRouterRouting(order: ["anthropic"], allowsFallbacks: false)
            let session = LanguageModelSession(
                model: model.languageModel(routing: routing), instructions: longInstructions(tokens: 2_500))

            let first = try await session.respond(to: "Reply with OK.", options: LiveTests.short)
            let second = try await session.respond(to: "Reply with OK again.", options: LiveTests.short)

            record([first.usage, second.usage], named: "usage.txt")
            let providers = [first, second].map { response in
                lastAnswer(in: response.transcriptEntries).flatMap { metadataString($0.metadata, OpenRouterMetadataKey.provider) } ?? "none"
            }
            record(providers, named: "providers.txt")
            #expect(first.usage.input.cachedTokenCount == 0)
            #expect((metadataNumber(first.usage.metadata, OpenRouterMetadataKey.cacheWriteTokenCount) ?? 0) > 0)
            #expect(second.usage.input.cachedTokenCount >= 2_000)
            #expect(second.usage.input.cachedTokenCount <= second.usage.input.totalTokenCount)
            let firstCost = try #require(metadataNumber(first.usage.metadata, OpenRouterMetadataKey.cost))
            let secondCost = try #require(metadataNumber(second.usage.metadata, OpenRouterMetadataKey.cost))
            #expect(secondCost < firstCost)
        }

        @Test(arguments: bestEffortModels)
        func `a later turn reads the cached prompt`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel, instructions: longInstructions(tokens: 4_500))

            var turns: [LanguageModelSession.Response<String>] = []
            for turn in 1...3 {
                turns.append(try await session.respond(to: "Reply with OK for turn \(turn).", options: LiveTests.short))
                if turn > 1, turns[turn - 1].usage.input.cachedTokenCount > 0 { break }
                try await Task.sleep(for: .seconds(2))
            }

            record(turns.map(\.usage), named: "usage.txt")
            for response in turns {
                #expect(response.usage.input.cachedTokenCount <= response.usage.input.totalTokenCount)
            }
            withKnownIssue("This provider caches when it can, not on every request.", isIntermittent: true) {
                #expect(turns.dropFirst().contains { $0.usage.input.cachedTokenCount > 0 })
            }
        }

        /// Instructions of about the given length, starting with a value new to this run, so the first turn writes
        /// the cache instead of reading an earlier run's.
        private func longInstructions(tokens: Int) -> String {
            // Each rule is about 17 tokens.
            let rules = (1...(tokens / 17 + 1)).map { number in
                "Rule \(number): when asked about item \(number), answer with the code \(String(number, radix: 36).uppercased())."
            }
            return (["Run \(UUID().uuidString). Follow these rules."] + rules).joined(separator: "\n")
        }
    }

    @Suite("Reasoning")
    struct Reasoning {
        /// Models that reason, at a level that keeps them reasoning. Haiku 4.5 thinks on every request with reasoning
        /// on, where Haiku 5.5's adaptive thinking skips a simple turn.
        static let models = [
            LiveModel(.anthropicClaudeHaiku4_5, signsReasoning: true),
            LiveModel(.googleGemini3_1FlashLite, signsReasoning: true),
            LiveModel(.openaiGpt5Nano, signsReasoning: true),
            LiveModel(.deepseekDeepseekV4Flash, reasoningLevel: .deep),
        ]

        @Test(arguments: models)
        func `reasoning replays through a tool loop and the next turn`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel, tools: [WeatherTool()])
            let options = ContextOptions(reasoningLevel: model.reasoningLevel)

            let first = try await session.respond(to: "How warm is it in Lisbon right now? Use the tool.", contextOptions: options)
            let second = try await session.respond(to: "And in Porto? Use the tool.", contextOptions: options)

            record(session.transcript, named: "transcript.txt")
            #expect(first.content.contains("17"))
            #expect(second.content.contains("17"))
            let cities = try session.transcript.weatherCities()
            #expect(cities.contains { $0.localizedCaseInsensitiveContains("Lisbon") })
            #expect(cities.contains { $0.localizedCaseInsensitiveContains("Porto") })

            let reasoning = try #require(reasoningEntries(in: first.transcriptEntries).first)
            let details = try reasoningDetails(of: reasoning)
            record(details, named: "reasoning-details.txt")
            #expect(!details.isEmpty)
            if model.signsReasoning {
                #expect(details.contains { $0["signature"]?.stringValue != nil || $0["data"]?.stringValue != nil })
            }
        }
    }

    @Suite("Errors")
    struct Errors {
        @Test func `a rejected key throws OpenRouter's 401`() async throws {
            let model = OpenRouterLanguageModel(.openaiGpt4_1Nano) { "sk-or-v1-not-a-key" }

            let error = try await #require(throws: OpenRouterError.self) {
                try await LanguageModelSession(model: model).respond(to: "Hi", options: LiveTests.short)
            }

            record(error, named: "error.txt")
            #expect(error.status == 401)
        }

        @Test func `an unknown model is rejected`() async throws {
            let details = OpenRouterModel<ContextOptions.ReasoningLevel>(
                id: "swift-language-models/no-such-model",
                displayName: "No such model",
                releaseDate: .now,
                supportedParameters: []
            )
            let model = LiveModel(details).languageModel

            let error = try await #require(throws: OpenRouterError.self) {
                try await LanguageModelSession(model: model).respond(to: "Hi")
            }

            record(error, named: "error.txt")
            #expect([400, 404].contains(error.status))
        }

        @Test func `a prompt longer than the context throws with both sizes`() async throws {
            let session = LanguageModelSession(model: LiveModel(.microsoftPhi4).languageModel)

            let error = try await #require(throws: LanguageModelError.self) {
                try await session.respond(to: String(repeating: "word ", count: 20_000), options: LiveTests.short)
            }

            record(error, named: "error.txt")
            guard case .contextSizeExceeded(let context) = error else {
                Issue.record("Expected the context size to be exceeded, got \(error)")
                return
            }
            #expect(context.contextSize == 16_384)
            #expect(context.tokenCount > 16_384)
        }
    }

    /// Probes of the ways the executor may break on some models, each named after its risk. A probe that fails today
    /// runs in a known issue, so it reports once the risk is fixed. A probe of a risk that OpenRouter turned out to
    /// handle stays as a regression test. Risk 4 is probed by the parallel calls in Tools.
    @Suite("Executor risks")
    struct ExecutorRisks {
        /// Models whose hosts need the tool definitions whenever the history has tool calls: Anthropic, and Bedrock,
        /// the only host of Nova.
        static let toolHistoryModels = [LiveModel(.anthropicClaudeHaiku5_5), LiveModel(.amazonNovaMicroV1)]

        /// Models that reason in plain text, which some hosts stream as `reasoning` next to empty `reasoning_details`.
        static let plainTextReasoningModels = [
            LiveModel(.deepseekDeepseekV4Flash, reasoningLevel: .deep),
            LiveModel(.zAiGlm5_3Flash),
            LiveModel(.xiaomiMimoV2_6Flash),
            LiveModel(.qwenQwen3_7Flash),
        ]

        /// Models that reject encrypted reasoning another model wrote.
        static let handoffModels = [LiveModel(.deepseekDeepseekV4Flash), LiveModel(.googleGemini3_1FlashLite)]

        /// Risk 1, which OpenRouter handles: with tool calls disallowed, Foundation Models sends no tools, so a history
        /// with tool calls goes out without their definitions, and Anthropic and Bedrock still accept it.
        @Test(arguments: toolHistoryModels)
        func `a turn with tools disallowed after a tool call keeps the history valid`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel, tools: [WeatherTool()])
            defer { record(session.transcript, named: "transcript.txt") }
            _ = try await session.respond(to: "How warm is it in Lisbon right now? Use the tool.")
            try #require(!session.transcript.toolCalls.isEmpty)

            let response = try await session.respond(
                to: "Which city did you just check? Reply with its name only.",
                options: GenerationOptions(toolCallingMode: .disallowed)
            )

            #expect(response.content.localizedCaseInsensitiveContains("Lisbon"))
        }

        /// Risk 2: an empty `reasoning_details` in a delta wins over its `reasoning` text, so the text is lost.
        @Test(arguments: plainTextReasoningModels)
        func `reasoning in plain text reaches the transcript`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel)

            let response = try await session.respond(
                to: "What is 17 × 23? Reply with the number only.",
                contextOptions: ContextOptions(reasoningLevel: model.reasoningLevel)
            )

            record(response.transcriptEntries, named: "entries.txt")
            #expect(response.content.contains("391"))
            try #require(response.usage.output.reasoningTokenCount > 0, "The model didn't reason.")
            #expect(reasoningEntries(in: response.transcriptEntries).contains { !plainText($0.segments).isEmpty })
        }

        /// Risk 3: tool-call arguments are appended without checking that they're complete, so a host that repeats
        /// them gives `{…}{…}`. Kimi K2.6 is known to repeat a call.
        @Test func `a Kimi tool call arrives once with arguments that parse`() async throws {
            let session = LanguageModelSession(model: LiveModel(.moonshotaiKimiK2_6).languageModel, tools: [WeatherTool()])

            let response = try await session.respond(
                to: "How warm is it in Lisbon right now? Use the tool.",
                contextOptions: ContextOptions(reasoningLevel: .off)
            )

            record(session.transcript, named: "transcript.txt")
            #expect(try session.transcript.weatherCities().count == 1)
            #expect(response.content.contains("17"))
        }

        /// Risk 5, fixed: `<think>` inside the content became part of the answer. MiniMax M2 sends it on its own host,
        /// which takes no schema, so the probe reads plain text.
        @Test func `MiniMax's own host keeps its thinking out of the answer`() async throws {
            let routing = OpenRouterRouting(order: ["minimax"])
            let session = LanguageModelSession(model: LiveModel(.minimaxMinimaxM2).languageModel(routing: routing))

            let response = try await session.respond(to: "What is 17 × 23? Reply with the number only.")

            record(answerMetadata(response), named: "metadata.txt")
            record(response.transcriptEntries, named: "entries.txt")
            #expect(response.content.contains("391"))
            expectThinkingMovedToReasoning(in: response.transcriptEntries)
        }

        /// Risk 5 on Nova, which writes `<thinking>` before it calls a tool. The block goes back at the start of the
        /// answer's text, and Bedrock takes it, so the tool loop ends with the tool's answer.
        @Test func `Nova keeps its thinking out of the answer through a tool loop`() async throws {
            let session = LanguageModelSession(model: LiveModel(.amazonNovaMicroV1).languageModel, tools: [WeatherTool()])

            let response = try await session.respond(to: "How warm is it in Lisbon right now? Use the tool.")

            record(session.transcript, named: "transcript.txt")
            #expect(response.content.contains("17"))
            expectThinkingMovedToReasoning(in: response.transcriptEntries)
        }

        /// Expects no answer among the entries to hold a `<think>` or `<thinking>` tag, and a reasoning entry to hold
        /// the text between them.
        private func expectThinkingMovedToReasoning(in entries: some Sequence<Transcript.Entry>) {
            let answers = entries.compactMap { entry in if case .response(let answer) = entry { plainText(answer.segments) } else { nil } }
            #expect(!answers.contains { $0.contains("<think") })
            #expect(reasoningEntries(in: entries).contains { !plainText($0.segments).isEmpty })
        }

        /// Risk 6: ids from another provider go back as they are, though Mistral takes only 9 letters and digits.
        /// Mistral's own host accepts them through OpenRouter all the same.
        @Test func `another provider's tool-call ids work on Mistral's own host`() async throws {
            let first = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel, tools: [WeatherTool()])
            _ = try await first.respond(to: "How warm is it in Lisbon right now? Use the tool.")
            try #require(!first.transcript.toolCalls.isEmpty)
            let model = LiveModel(.mistralaiMistralNemo).languageModel(routing: LiveTests.mistralHost)
            let second = LanguageModelSession(model: model, tools: [WeatherTool()], transcript: first.transcript)

            defer { record(second.transcript, named: "transcript.txt") }

            let response = try await second.respond(to: "And in Porto? Use the tool.")

            #expect(response.content.contains("17"))
        }

        /// Risk 6, the other half: an id is made up as `call_<UUID>` when the model sends none, which Mistral would
        /// reject on the next request.
        @Test func `a tool round trip on Mistral's own host keeps its 9-character ids`() async throws {
            let model = LiveModel(.mistralaiMistralNemo).languageModel(routing: LiveTests.mistralHost)
            let session = LanguageModelSession(model: model, tools: [WeatherTool()])

            let response = try await session.respond(to: "How warm is it in Lisbon right now? Use the tool.")

            record(session.transcript, named: "transcript.txt")
            let ids = session.transcript.toolCalls.map(\.id)
            #expect(!ids.isEmpty)
            #expect(ids.allSatisfy { $0.wholeMatch(of: /[A-Za-z0-9]{9}/) != nil })
            #expect(response.content.contains("17"))
        }

        /// Risk 7, which OpenRouter handles: an empty tool output goes out as `content: ""`, and Bedrock, which rejects
        /// blank text, still accepts it.
        @Test func `an empty tool output is accepted on Bedrock`() async throws {
            let session = LanguageModelSession(model: LiveModel(.amazonNovaMicroV1).languageModel, tools: [SilentTool()])
            defer { record(session.transcript, named: "transcript.txt") }

            let response = try await session.respond(to: "Log a visit to Lisbon with the tool, then reply with OK.")

            #expect(session.transcript.toolCalls.contains { $0.toolName == "logVisit" }, "The model never called the tool.")
            #expect(!response.content.isEmpty)
        }

        /// Risk 8, fixed: `.required` is refused before any request on a model without `tool_choice`, such as Nova,
        /// where it used to be dropped, and Nova answered without a tool call.
        @Test func `a required tool call is refused on a model without tool_choice`() async throws {
            let session = LanguageModelSession(model: LiveModel(.amazonNovaMicroV1).languageModel, tools: [WeatherTool()])

            let error = try await #require(throws: LanguageModelError.self) {
                try await session.respond(to: "Say hello.", options: GenerationOptions(toolCallingMode: .required))
            }

            record(error, named: "error.txt")
            guard case .unsupportedCapability(let unsupported) = error else {
                Issue.record("Expected an unsupported capability, got \(error)")
                return
            }
            #expect(unsupported.capability == .toolCalling)
        }

        /// Risk 9, which OpenRouter handles: a request with a schema asks for hosts that honor every parameter, and
        /// Kimi K2.6 still has one for a strict schema.
        @Test func `a strict schema finds a Kimi host`() async throws {
            let session = LanguageModelSession(model: LiveModel(.moonshotaiKimiK2_6).languageModel)

            let trip = try await session.respond(
                to: "Plan a short trip to Lisbon.",
                generating: Trip.self,
                contextOptions: ContextOptions(includeSchemaInPrompt: true, reasoningLevel: .off)
            ).content

            record(trip, named: "trip.txt")
            #expect(trip.activities.count == 3)
        }

        /// Risk 10, which OpenRouter handles: reasoning that a model none of the request names wrote still goes back,
        /// so a transcript moved to another model resends the first model's encrypted reasoning, which DeepSeek and
        /// Gemini accept.
        @Test(arguments: handoffModels)
        func `a transcript with another model's encrypted reasoning moves to a new model`(model: LiveModel) async throws {
            let first = LanguageModelSession(model: LiveModel(.openaiGpt5Nano).languageModel, tools: [WeatherTool()])
            _ = try await first.respond(
                to: "How warm is it in Lisbon right now? Use the tool.",
                contextOptions: ContextOptions(reasoningLevel: .light)
            )
            let details = try reasoningEntries(in: first.transcript).flatMap(reasoningDetails(of:))
            try #require(details.contains { $0["type"] == "reasoning.encrypted" }, "gpt-5-nano sent no encrypted reasoning.")
            let second = LanguageModelSession(model: model.languageModel, tools: [WeatherTool()], transcript: first.transcript)
            defer { record(second.transcript, named: "transcript.txt") }

            let response = try await second.respond(to: "And in Porto? Use the tool.")

            #expect(response.content.contains("17"))
        }

        /// Risk 11: reasoning text without a format counts as Anthropic's, so GLM's unsigned reasoning is dropped when
        /// it's replayed. The next request goes to a stub, which shows what would go back.
        @Test func `GLM's unsigned reasoning goes back on the next request`() async throws {
            let glm = LiveModel(.zAiGlm5_3Flash)
            let session = LanguageModelSession(model: glm.languageModel, tools: [WeatherTool()])
            _ = try await session.respond(
                to: "How warm is it in Lisbon right now? Use the tool.",
                contextOptions: ContextOptions(reasoningLevel: glm.reasoningLevel)
            )
            let reasoning = reasoningEntries(in: session.transcript)
            record(try reasoning.map(reasoningDetails(of:)), named: "reasoning-details.txt")
            guard reasoning.contains(where: { !plainText($0.segments).isEmpty }) else {
                try Test.cancel("GLM sent no reasoning text, so there's nothing to replay.")
            }

            let stub = HTTPStub(events(text("OK"), done()))
            let replay = OpenRouterLanguageModel(glm.details, baseURL: stub.baseURL, session: stub.session) { "sk-or-replay" }
            _ = try await LanguageModelSession(model: replay, tools: [WeatherTool()], transcript: session.transcript).respond(to: "Thanks.")

            let assistant = try assistantMessages(stub)
            record(assistant, named: "replayed-assistant-messages.txt")
            #expect(assistant.contains { $0["reasoning"]?.stringValue?.isEmpty == false })
            #expect(assistant.contains { elements($0["reasoning_details"]).contains { $0["type"] == "reasoning.text" } })
        }

        /// Risk 12, fixed: the catalog's prices include the fees on top of tokens, so an estimate from them accounts for
        /// Perplexity's search on every request.
        @Test func `the catalog's prices account for what a Perplexity answer costs`() async throws {
            let model = LiveModel(.perplexitySonar)
            let session = LanguageModelSession(model: model.languageModel)

            let response = try await session.respond(to: "Reply with the single word: hello", options: LiveTests.short)

            record(answerMetadata(response), named: "metadata.txt")
            let cost = try #require(metadataNumber(response.usage.metadata, OpenRouterMetadataKey.cost))
            let input = response.usage.input.totalTokenCount
            let pricing = try #require(model.details.pricing).prices(forPromptTokens: input)
            // Sonar searches once for every request.
            let fees = (pricing.request ?? 0) + (pricing.webSearch ?? 0)
            let estimate = NSDecimalNumber(
                decimal: Decimal(input) * pricing.prompt + Decimal(response.usage.output.totalTokenCount) * pricing.completion + fees
            ).doubleValue
            #expect(cost <= 2 * estimate + 0.000_01, "It cost \(cost), and the catalog's prices give \(estimate).")
            #expect(estimate <= 2 * cost, "It cost \(cost), and the catalog's prices give \(estimate).")
        }
    }

    @Suite(
        "Free models",
        .enabled(
            if: ProcessInfo.processInfo.environment["LIVE_FREE"]?.isEmpty == false,
            "Set LIVE_FREE to spend the account's daily free requests"
        )
    )
    struct FreeModels {
        @Test func `a free model answers at no cost`() async throws {
            let session = LanguageModelSession(model: LiveModel(.nvidiaNemotron3_5LightningFree).languageModel)

            do {
                let response = try await session.respond(
                    to: "Reply with the single word: hello",
                    options: GenerationOptions(maximumResponseTokens: 64),
                    contextOptions: ContextOptions(reasoningLevel: .off)
                )
                record(answerMetadata(response), named: "metadata.txt")
                #expect(!response.content.isEmpty)
                #expect(metadataNumber(response.usage.metadata, OpenRouterMetadataKey.cost) == 0)
            } catch let error as LanguageModelError {
                guard case .rateLimited = error else { throw error }
                record(error, named: "error.txt")
                try Test.cancel("The free model is rate limited: \(error)")
            }
        }
    }
}

/// A list long enough to stream in many snapshots.
@Generable
private struct PackingList {
    @Guide(description: "Forty short items, each a few words.", .count(40))
    var items: [String]
}

/// A tool without arguments, whose answer the model can't know.
private struct AccessCodeTool: Tool {
    let name = "getAccessCode"
    let description = "Gets today's access code. It takes no arguments."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        "Today's access code is K7Q2."
    }
}

/// A tool that returns its text, for checking how arguments survive the trip.
private struct EchoTool: Tool {
    let name = "echo"
    let description = "Returns the given text unchanged."

    @Generable
    struct Arguments {
        @Guide(description: "The text to return, exactly as given.")
        var text: String
    }

    func call(arguments: Arguments) async throws -> String {
        arguments.text
    }
}

/// A tool whose output is empty.
private struct SilentTool: Tool {
    let name = "logVisit"
    let description = "Logs a visit to a city. It returns nothing."

    @Generable
    struct Arguments {
        @Guide(description: "The city's name.")
        var city: String
    }

    func call(arguments: Arguments) async throws -> String {
        ""
    }
}

/// A weather tool that ends the answer with ``ToolCallInterruption`` when it's called, so a test sees the first call
/// and no more.
private struct InterruptingWeatherTool: Tool {
    let name = "getWeather"
    let description = "Gets the current temperature in a city, in degrees Celsius."

    @Generable
    struct Arguments {
        @Guide(description: "The city's name.")
        var city: String
    }

    func call(arguments: Arguments) async throws -> String {
        throw ToolCallInterruption()
    }
}

/// The error that ``InterruptingWeatherTool`` throws.
private struct ToolCallInterruption: Error {}

/// Sends a prompt and stops at the first call of an ``InterruptingWeatherTool``, since a required tool choice stays on
/// for every round, and a model that honors it never stops calling tools.
///
/// The session keeps the transcript of the answer that the tool ended, so a test can read the call; by default a
/// failed answer is reverted.
///
/// - Returns: The response, or `nil` when the model called the tool.
private func respondUntilToolCall(
    _ session: LanguageModelSession,
    to prompt: String,
    options: GenerationOptions
) async throws -> LanguageModelSession.Response<String>? {
    session.transcriptErrorHandlingPolicy = .preserveTranscript
    do {
        return try await session.respond(to: prompt, options: options)
    } catch let error as LanguageModelSession.ToolCallError where error.underlyingError is ToolCallInterruption {
        return nil
    }
}
