import APIFormat
import Foundation
import FoundationModels
import LanguageModels

/// One answer's stream: turns a dialect's chunks into the answer's output, which an ``AnswerChannel`` sends as
/// Foundation Models channel events.
///
/// Reasoning arrives in the provider's members, and tool-call fragments by index, so parallel calls form one round.
/// Each piece of data the model generates becomes a data entry of its own. The answer ends with its metadata and usage
/// on the entry that finishes it, and with the pages it cites on its response entry.
struct AnswerStream<Dialect: ChatCompletionsDialect> {
    private let dialect: Dialect
    private let imageEntries: [Transcript.Entry]
    private let requiresCompleteAnswer: Bool

    /// What the answer's chunks reported about it so far.
    private(set) var facts = AnswerReport()

    /// What the dialect tracks across the answer.
    private(set) var state: Dialect.StreamState

    private var output: AnswerChannel
    private var refusal = ""

    /// Starts the stream of an answer.
    ///
    /// - Parameters:
    ///   - channel: Where the answer's events go.
    ///   - dialect: The provider's dialect.
    ///   - headers: The headers of the response whose stream carries the answer.
    ///   - imageEntries: The request's entries that carry an image, which an error for an image the host rejects names.
    ///   - requiresCompleteAnswer: Whether an answer cut off at its token limit is an error, as for guided generation,
    ///     where a partial answer would decode as a wrong value.
    init(
        channel: LanguageModelExecutorGenerationChannel, dialect: Dialect, headers: ResponseHeaders,
        imageEntries: [Transcript.Entry], requiresCompleteAnswer: Bool
    ) {
        self.dialect = dialect
        self.imageEntries = imageEntries
        self.requiresCompleteAnswer = requiresCompleteAnswer
        output = AnswerChannel(channel: channel, origin: Dialect.reasoningOrigin)
        state = dialect.streamState(headers)
    }

    /// The text sent to the response entry, or empty when the answer ends in tool calls, since the round that answers
    /// them comes after.
    var responseText: String {
        output.responseText
    }

    /// Whether any of the answer's output has arrived: text, reasoning or a tool call.
    var hasOutput: Bool {
        output.hasOutput
    }

    /// Sends the events for one server-sent event.
    ///
    /// - Returns: Whether the event is the `[DONE]` that ends the stream.
    /// - Throws: The dialect's error for an event that isn't a chunk, and for an error event.
    mutating func receive(_ event: ServerSentEvent) async throws -> Bool {
        let streamEvent: ChatCompletionChunk.StreamEvent?
        do {
            streamEvent = try ChatCompletionChunk.StreamEvent(event)
        } catch {
            throw unreadable(error)
        }
        switch streamEvent {
        case .chunk(let chunk, let data)?:
            try await receive(chunk, data: data)
            return false
        case .done?:
            return true
        case nil:
            return false
        }
    }

    private mutating func receive(_ chunk: ChatCompletionChunk, data: Data) async throws {
        facts.update(with: chunk)
        let extras: Dialect.ChunkExtras
        do {
            extras = try ProviderHTTP.decoder.decode(Dialect.ChunkExtras.self, from: data)
        } catch {
            throw unreadable(error)
        }
        let extrasOutput = dialect.observe(extras, into: &state)
        if let error = chunk.error, error != .null {
            let body: Dialect.ErrorBody
            do {
                body = try ProviderHTTP.decoder.decode(ErrorEvent.self, from: data).error
            } catch {
                throw unreadable(error)
            }
            throw failure(.errorEvent(body))
        }
        guard let delta = chunk.choices?.first?.delta else { return }

        if let reasoning = extrasOutput.reasoning { await output.appendReasoning(reasoning, model: facts.model) }
        if let content = delta.content, !content.isEmpty {
            await output.appendText(content, model: facts.model)
        }
        if let text = delta.refusal { refusal += text }
        for annotation in delta.annotations ?? [] {
            guard let found = annotation.urlCitation, let citation = Citation(found) else { continue }
            output.cite(citation)
        }
        for fragment in delta.toolCalls ?? [] {
            await output.addToolCall(
                index: fragment.index, id: fragment.id, name: fragment.function?.name, arguments: fragment.function?.arguments)
        }
        for generated in extrasOutput.generatedData {
            await output.sendData(generated)
        }
    }

    /// Sends the events that end the answer: arguments for calls that had none, the reasoning signature, and the
    /// metadata and usage.
    ///
    /// An answer cut off at its token limit ends like any other, with `length` as its finish reason, since Foundation
    /// Models has no error for it. One cut off inside its tool calls throws instead, so no tool gets partial arguments,
    /// and so does a guided answer, which would decode as a wrong value.
    ///
    /// - Parameter isComplete: Whether the stream ended with `[DONE]`. A stream that ends without it or a finish reason
    ///   was cut off.
    /// - Throws: `LanguageModelError.refusal` or `.guardrailViolation` when the model declined or a filter stopped it,
    ///   `GeneratedContent.ParsingError` when a guided answer reached its token limit, and the dialect's error when the
    ///   stream was cut off, ended in an error, reached its token limit inside a tool call, or had a call that never
    ///   got its name.
    mutating func finish(isComplete: Bool) async throws {
        guard isComplete || facts.finishReason != nil else {
            throw failure(.unusableResponse(.cutOff))
        }
        await output.finishText(model: facts.model)
        if let error = endingError { throw error }
        do {
            try await output.finishToolCalls()
        } catch .missingName {
            throw failure(.unusableResponse(.toolCallWithoutName))
        } catch .incompleteArguments(let toolName) {
            throw failure(.unusableResponse(.incompleteToolArguments(toolName: toolName)))
        }
        await output.end(report: facts, facts: dialect.facts(of: state))
    }

    /// The error that the answer ends in although it arrived whole: a refusal, a content filter, the host's failure,
    /// or the token limit reached inside a tool call or a guided answer. `nil` when it ended well.
    private var endingError: (any Error)? {
        let metadata = LanguageModelError.failureMetadata(status: nil, code: nil, provider: dialect.facts(of: state).host)
        if !refusal.isEmpty {
            return LanguageModelError(.refusal, message: refusal, metadata: metadata)
        }
        if facts.finishReason == .contentFilter {
            return LanguageModelError(.guardrailViolation, message: "A content filter stopped the response.", metadata: metadata)
        }
        switch facts.finishReason {
        case .error?:
            return failure(.failedAnswer)
        case .length? where output.hasToolCalls:
            return failure(.unusableResponse(.tokenLimitInToolCall))
        case .length? where requiresCompleteAnswer:
            return GeneratedContent.ParsingError(
                rawContent: responseText, debugDescription: "The answer reached its token limit before it was complete.")
        default:
            return nil
        }
    }

    /// The error the answer's failure becomes, with what the dialect tracked so far.
    private func failure(_ kind: ChatCompletionsFailure<Dialect>.Kind) -> any Error {
        dialect.error(for: ChatCompletionsFailure(kind, state: state, imageEntries: imageEntries)).error
    }

    /// The error for an event whose data can't be read, with the reason.
    private func unreadable(_ error: any Error) -> any Error {
        failure(.unusableResponse(.unreadableEvent("\(error)")))
    }
}

extension AnswerStream {
    /// The event of a chunk whose `error` member is set, with the error in the dialect's type.
    private struct ErrorEvent: Decodable {
        let error: Dialect.ErrorBody
    }
}

extension FinishReason {
    /// The format's reason for an answer a content filter stopped, which throws instead of ending an entry.
    fileprivate static let contentFilter: Self = "content_filter"

    /// The reason for an answer that ended in the host's failure, which throws instead of ending an entry.
    fileprivate static let error: Self = "error"
}

extension Citation {
    /// The citation of a streamed annotation, or `nil` when it has no valid URL.
    fileprivate init?(_ citation: ChatCompletionChunk.Annotation.URLCitation) {
        guard let address = citation.url, let url = URL(string: address) else { return nil }
        self.init(
            url: url, title: citation.title, excerpt: citation.content, startOffset: citation.startIndex, endOffset: citation.endIndex)
    }
}
