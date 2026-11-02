import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing
import UniformTypeIdentifiers

@testable import OpenRouterLanguageModels

/// A session that the exact-exchange tests run against a stub, and what it sent and got back, read through Foundation
/// Models' public API.
///
/// Each part is text, so a test compares the whole exchange at once: every request body as its bytes spell it, the
/// session's transcript after the answer, the answer's usage, a streamed answer's last snapshot, and the error
/// it ended in. Entry ids that the framework makes up are left out; tool call ids, which the host sends, are kept.
struct ExactExchange {
    /// The request bodies the host received, in order.
    var bodies: [String] = []

    /// The OpenRouter headers of each request, sorted by name.
    var headers: [[String]] = []

    /// Each entry of the session's transcript once the answer ended, or once it failed.
    var transcript: [String] = []

    /// The answer's usage, or `nil` when it failed.
    var usage: String?

    /// The last snapshot a streamed answer yielded: its raw content, then its entries. Earlier snapshots aren't kept,
    /// since the framework merges the events that arrive between two reads into one, so how many there are and what
    /// each holds depends on timing.
    var lastSnapshot: String?

    /// The error the answer ended in, or `nil` when it ended well.
    var error: String?
}

extension ExactExchange {
    /// Runs a session against a stub and reads what it sent and got back.
    ///
    /// - Parameters:
    ///   - stub: The host, which records each request.
    ///   - session: The session to run.
    ///   - answer: Sends the prompt and returns the answer's usage, keeping the last snapshot of a streamed answer.
    init(
        _ stub: HTTPStub,
        _ session: LanguageModelSession,
        answer: (LanguageModelSession, inout String?) async throws -> LanguageModelSession.Usage
    ) async {
        var lastSnapshot: String?
        do {
            usage = Self.description(of: try await answer(session, &lastSnapshot))
        } catch {
            self.error = String(describing: error)
        }
        self.lastSnapshot = lastSnapshot
        transcript = session.transcript.map(Self.description(of:))
        // The session's id is its first prompt's, which the framework makes up, and a JPEG's bytes depend on the
        // system's encoder.
        func steady(_ text: String) -> String {
            text.replacing(/[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/, with: "<generated id>")
                .replacing(/data:image\/jpeg;base64,[A-Za-z0-9+\/=]+/, with: "data:image/jpeg;base64,<jpeg>")
        }
        bodies = stub.requests.map { steady(String(decoding: $0.body, as: UTF8.self)) }
        headers = stub.requests.map { recorded in
            (recorded.request.allHTTPHeaderFields ?? [:]).filter { $0.key.hasPrefix("X-") || $0.key == "HTTP-Referer" }
                .map { steady("\($0.key): \($0.value)") }.sorted()
        }
    }

    /// Streams an answer, keeping its last snapshot, and returns the answer's usage.
    static func stream(
        _ stream: LanguageModelSession.ResponseStream<String>,
        into lastSnapshot: inout String?
    ) async throws -> LanguageModelSession.Usage {
        for try await snapshot in stream {
            lastSnapshot = "\(JSONValue(snapshot.rawContent).text) \(snapshot.transcriptEntries.map(description(of:)))"
        }
        return try await stream.collect().usage
    }

    /// An entry without its id: its kind, text, metadata and the parts that matter for it.
    static func description(of entry: Transcript.Entry) -> String {
        switch entry {
        case .instructions(let instructions):
            return "instructions \(description(of: instructions.segments)) tools: \(instructions.toolDefinitions.map(\.name))"
        case .prompt(let prompt):
            return "prompt \(description(of: prompt.segments)) metadata: \(description(of: prompt.metadata))"
        case .reasoning(let reasoning):
            let signature = reasoning.signature.map(description(of:)) ?? "nil"
            let metadata = description(of: reasoning.metadata)
            return "reasoning \(description(of: reasoning.segments)) metadata: \(metadata) signature: \(signature)"
        case .response(let response):
            return "response \(description(of: response.segments)) metadata: \(description(of: response.metadata))"
        case .toolCalls(let calls):
            let texts = calls.map { call in
                "\(call.id) \(call.toolName) \(JSONValue(call.arguments).text) metadata: \(description(of: call.metadata))"
            }
            return "toolCalls \(texts)"
        case .toolOutput(let output):
            return "toolOutput \(output.id) \(output.toolName) \(description(of: output.segments))"
        default:
            #if canImport(FoundationModels, _version: 2.1.14)
            if #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *), case .data(let data) = entry {
                return "data \(data.contentType.identifier) \(description(of: data.content)) metadata: \(JSONValue(data.metadata).text)"
            }
            #endif
            return "another kind of entry"
        }
    }

    /// Usage as its token counts and metadata.
    static func description(of usage: LanguageModelSession.Usage) -> String {
        """
        input \(usage.input.totalTokenCount) cached \(usage.input.cachedTokenCount), output \(usage.output.totalTokenCount) \
        reasoning \(usage.output.reasoningTokenCount), metadata: \(description(of: usage.metadata))
        """
    }

    private static func description(of segments: [Transcript.Segment]) -> String {
        "[" + segments.map(description(of:)).joined(separator: ", ") + "]"
    }

    private static func description(of segment: Transcript.Segment) -> String {
        switch segment {
        case .text(let text): JSONValue.string(text.content).text
        case .structure(let structure): JSONValue(structure.content).text
        case .attachment(let attachment): "attachment \(attachment.label ?? "unlabeled")"
        @unknown default: "another kind of segment"
        }
    }

    /// Metadata as JSON, with its keys sorted.
    private static func description(of metadata: [String: GeneratedContent]) -> String {
        JSONValue.object(JSONObject(metadata.map { .init(key: $0.key, value: JSONValue($0.value)) }).sortedByKey()).text
    }

    /// Data as UTF-8 text when it is, otherwise as Base64.
    private static func description(of data: Data) -> String {
        String(data: data, encoding: .utf8).map { JSONValue.string($0).text } ?? data.base64EncodedString()
    }
}

extension ExactExchange {
    /// Streamed text alone, with instructions, sampling, a token limit, metadata, OpenRouter's settings and a cache mark.
    static func textAlone() async -> ExactExchange {
        let stub = HTTPStub(
            events(
                text("The plan "), adding(["service_tier": "flex"], to: text("starts Monday.")),
                done(prompt: 12, cached: 4, cacheWrite: 2, completion: 5)))
        let options = OpenRouterOptions(
            frequencyPenalty: 0.5, presencePenalty: 0.2, stopSequences: ["END"], logitBias: [13: 2.5, 50_256: -100], verbosity: .low,
            serviceTier: .flex, endUserID: "user-1")
        let model: OpenRouterLanguageModel<Efforts.Unsupported> = model(
            stub, parameters: chatParameters.union([.frequencyPenalty, .stop, .logitBias, .verbosity, .maxCompletionTokens]),
            cachesOnlyMarkedPrompts: true, options: options)
        let generation = GenerationOptions(
            samplingMode: .random(probabilityThreshold: 0.9, seed: 7), temperature: 0.5, maximumResponseTokens: 100)
        return await ExactExchange(stub, LanguageModelSession(model: model, instructions: "Be brief.")) { session, lastSnapshot in
            try await stream(
                session.streamResponse(to: "Plan the week.", options: generation, metadata: ["team": "coach", "count": 3]),
                into: &lastSnapshot)
        }
    }

    /// A streamed answer that calls a tool twice at once, then the answer to the tools' outputs.
    static func parallelTools() async -> ExactExchange {
        let stub = HTTPStub(
            events(
                text("Looking both up. "), toolCall(0, id: "call_1", name: "lookUpFood", arguments: #"{"food""#),
                toolCall(1, id: "call_2", name: "lookUpFood", arguments: #"{"food":"rice"}"#),
                toolCall(0, arguments: #":"egg"}"#), done("tool_calls")),
            events(text("An egg and rice have 100 kcal each."), done()))
        let model: OpenRouterLanguageModel<Efforts.Unsupported> = model(stub, options: OpenRouterOptions(parallelToolCalls: .allowed))
        return await ExactExchange(stub, LanguageModelSession(model: model, tools: [FoodTool()])) { session, lastSnapshot in
            try await stream(session.streamResponse(to: "Calories in an egg and rice?"), into: &lastSnapshot)
        }
    }

    /// Guided generation whose host rejects a constraint of the schema, so the request goes again with the portable
    /// schema.
    static func portableSchemaRetry() async -> ExactExchange {
        let rejection = #"""
            {"error":{"code":400,"message":"Provider returned error","metadata":{"provider_name":"Seed","raw":"Keyword 'maximum' is not supported for type 'integer'"}}}
            """#
        let stub = HTTPStub(.json(rejection, status: 400), events(text(#"{"stars":4,"#), text(#""reason":"Tasty."}"#), done()))
        let model: OpenRouterLanguageModel<Efforts.Unsupported> = model(stub)
        return await ExactExchange(stub, LanguageModelSession(model: model)) { session, _ in
            try await session.respond(to: "Rate the soup.", generating: SoupRating.self).usage
        }
    }

    #if canImport(FoundationModels, _version: 2.1.14)
    /// An earlier prompt with an image, a labeled PDF and audio, which go back with the next prompt.
    @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
    static func attachments() async throws -> ExactExchange {
        let stub = HTTPStub(events(text("A menu, a photo and a song."), done()))
        let photo = Transcript.ImageAttachment(try #require(TestImage.halves(width: 8, height: 4)))
        let pdf = Transcript.DataAttachment(contentType: .pdf, content: pdfDocument(showing: "Soup of the day"))
        let audio = Transcript.DataAttachment(contentType: .wav, content: Data("RIFF-wave".utf8))
        let transcript = Transcript(entries: [
            .prompt(
                Transcript.Prompt(segments: [
                    .text(.init(content: "Keep these.")),
                    .attachment(.init(content: .image(photo), label: "Photo")),
                    .attachment(.init(content: .data(pdf), label: "Menu")),
                    .attachment(.init(content: .data(audio))),
                ])),
            .response(Transcript.Response(assetIDs: [], segments: [.text(.init(content: "Kept."))])),
        ])
        let model: OpenRouterLanguageModel<Efforts.Unsupported> = model(
            stub, inputs: [.text, .image, .file, .audio], options: OpenRouterOptions(pdfEngine: .mistralOCR))
        return await ExactExchange(stub, LanguageModelSession(model: model, transcript: transcript)) { session, _ in
            try await session.respond(to: "What's in these?").usage
        }
    }
    #endif

    /// A reasoning level, and a streamed answer that opens with reasoning in `<think>` tags split across deltas.
    static func taggedReasoning() async -> ExactExchange {
        let stub = HTTPStub(events(text("<thi"), text("nk>Count the days.</th"), text("ink>\n\nSeven"), text(" days."), done()))
        let model: OpenRouterLanguageModel<HighMediumLow> = model(stub, reasoning: .onByDefault, efforts: [.high, .medium, .low])
        return await ExactExchange(stub, LanguageModelSession(model: model)) { session, lastSnapshot in
            try await stream(
                session.streamResponse(to: "How many days in a week?", contextOptions: ContextOptions(reasoningLevel: .moderate)),
                into: &lastSnapshot)
        }
    }

    /// An earlier answer's reasoning details going back, and a streamed answer with new ones.
    static func reasoningDetails() async -> ExactExchange {
        let stub = HTTPStub(
            events(
                reasoning(["type": "reasoning.text", "text": "Two ", "index": 0, "format": "anthropic-claude-v1"]),
                reasoning(["type": "reasoning.text", "text": "weeks.", "index": 0]),
                reasoning(["type": "reasoning.text", "signature": "sig-2", "index": 0]),
                reasoning(["type": "reasoning.encrypted", "data": "blob", "index": 1]),
                text("Fourteen."), done(reasoning: 3)))
        let details: JSONValue = [
            ["type": "reasoning.text", "text": "Count them.", "signature": "sig-1", "format": "anthropic-claude-v1", "index": 0]
        ]
        let earlierReasoning = Transcript.Reasoning(
            metadata: [ReasoningOrigin.metadataKey: "openrouter", LanguageModelMetadataKey.model: "vendor/model"],
            segments: [.text(.init(content: "Count them."))], signature: details.data)
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(.init(content: "How many days in a week?"))])),
            .reasoning(earlierReasoning),
            .response(Transcript.Response(assetIDs: [], segments: [.text(.init(content: "Seven."))])),
        ])
        let model: OpenRouterLanguageModel<Efforts.Unsupported> = model(stub, reasoning: .onByDefault)
        return await ExactExchange(stub, LanguageModelSession(model: model, transcript: transcript)) { session, lastSnapshot in
            try await stream(session.streamResponse(to: "And in a fortnight?"), into: &lastSnapshot)
        }
    }

    /// Fallbacks, a router among them, routing, a server tool, the response cache and the router's report.
    static func fallbacks() async -> ExactExchange {
        let report: JSONValue = ["strategy": "fallback", "attempt": 2, "region": "iad"]
        let stub = HTTPStub(
            events(
                headers: ["X-OpenRouter-Cache-Status": "MISS"],
                adding(["model": "vendor/fallback"], to: text("Hello.")),
                adding(["model": "vendor/fallback", "openrouter_metadata": report], to: done())))
        let model: OpenRouterLanguageModel<Efforts.Unsupported> = model(
            stub, fallbacks: [fallback(), fallback("openrouter/auto")], serverTools: [.webSearch(maximumResults: 3)],
            routing: OpenRouterRouting(order: ["Anthropic"], fallbackProviders: .disallowed, sort: .price),
            responseCache: OpenRouterResponseCache(timeToLive: .seconds(600)),
            options: OpenRouterOptions(autoRouter: .init(allowedModels: ["anthropic/*"]), includesRouterMetadata: true))
        return await ExactExchange(stub, LanguageModelSession(model: model)) { session, _ in
            try await session.respond(to: "Hi").usage
        }
    }

    /// A streamed answer that an error event ends partway, after the response's HTTP 200.
    static func errorMidStream() async -> ExactExchange {
        let failure: JSONValue = [
            "error": [
                "code": 502, "message": "Provider returned error",
                "metadata": ["provider_name": "Vendor", "error_type": "provider_overloaded"],
            ]
        ]
        let stub = HTTPStub(events(text("Partial "), failure))
        let model: OpenRouterLanguageModel<Efforts.Unsupported> = model(stub)
        return await ExactExchange(stub, LanguageModelSession(model: model)) { session, lastSnapshot in
            try await stream(session.streamResponse(to: "Plan the week."), into: &lastSnapshot)
        }
    }

    /// A streamed answer whose stream stops before `[DONE]` and before any finish reason.
    static func cutOff() async -> ExactExchange {
        let stub = HTTPStub(unfinishedEvents(text("The plan")))
        let model: OpenRouterLanguageModel<Efforts.Unsupported> = model(stub)
        return await ExactExchange(stub, LanguageModelSession(model: model)) { session, lastSnapshot in
            try await stream(session.streamResponse(to: "Plan the week."), into: &lastSnapshot)
        }
    }
}

/// A rating whose stars have a range, which some hosts reject as a constraint of the schema.
@Generable
struct SoupRating {
    @Guide(description: "From 1 to 5", .range(1...5))
    var stars: Int

    var reason: String
}
