import Foundation
package import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

/// A session that the exact-exchange tests run against a stub, and what it sent and got back, read through Foundation
/// Models' public API.
///
/// Each part is text, so a test compares the whole exchange at once: every request body as its bytes spell it, the
/// session's transcript after the answer, the answer's usage, a streamed answer's last snapshot, and the error
/// it ended in. Entry ids that the framework makes up are left out; tool call ids, which the host sends, are kept.
package struct ExactExchange {
    /// The request bodies the host received, in order.
    package var bodies: [String] = []

    /// The headers of each request that the exchange records, sorted by name.
    package var headers: [[String]] = []

    /// Each entry of the session's transcript once the answer ended, or once it failed.
    package var transcript: [String] = []

    /// The answer's usage, or `nil` when it failed.
    package var usage: String?

    /// The last snapshot a streamed answer yielded: its raw content, then its entries. Earlier snapshots aren't kept,
    /// since the framework merges the events that arrive between two reads into one, so how many there are and what
    /// each holds depends on timing.
    package var lastSnapshot: String?

    /// The error the answer ended in, or `nil` when it ended well.
    package var error: String?
}

extension ExactExchange {
    /// Runs a session against a stub and reads what it sent and got back.
    ///
    /// - Parameters:
    ///   - stub: The host, which records each request.
    ///   - session: The session to run.
    ///   - headerNames: The names of the headers of each request that the exchange records, such as the provider's
    ///     own headers.
    ///   - answer: Sends the prompt and returns the answer's usage, keeping the last snapshot of a streamed answer.
    package init(
        _ stub: HTTPStub,
        _ session: LanguageModelSession,
        recordingHeaders headerNames: Regex<Substring>,
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
            (recorded.request.allHTTPHeaderFields ?? [:]).filter { $0.key.firstMatch(of: headerNames) != nil }
                .map { steady("\($0.key): \($0.value)") }.sorted()
        }
    }

    /// Streams an answer, keeping its last snapshot, and returns the answer's usage.
    package static func stream(
        _ stream: LanguageModelSession.ResponseStream<String>,
        into lastSnapshot: inout String?
    ) async throws -> LanguageModelSession.Usage {
        for try await snapshot in stream {
            lastSnapshot = "\(JSONValue(snapshot.rawContent).text) \(snapshot.transcriptEntries.map(description(of:)))"
        }
        return try await stream.collect().usage
    }

    /// An entry without its id: its kind, text, metadata and the parts that matter for it.
    package static func description(of entry: Transcript.Entry) -> String {
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
    package static func description(of usage: LanguageModelSession.Usage) -> String {
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
