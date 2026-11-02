import Foundation
import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

/// One answer's stream: turns a provider's chunks into Foundation Models channel events.
///
/// Each kind of output keeps one entry id for the whole answer, because the framework only merges events into the
/// entry they name. Reasoning text is shown until the answer's text starts. A block in `<think>` or `<thinking>` tags
/// that opens the answer's text is reasoning too, in arrival order with the provider's reasoning; the reasoning entry
/// keeps the block as the model wrote it, so it goes back where the model put it. Tool-call fragments are routed by
/// index into one tool-calls entry, so parallel calls form one round. Each piece of data the model generates becomes
/// a data entry of its own. The answer ends with its metadata and usage on the entry that finishes it, and with the
/// pages it cites on its response entry.
struct AnswerStream<Provider: ChatCompletionsProvider> {
    private let channel: LanguageModelExecutorGenerationChannel
    private let provider: Provider
    private let imageEntries: [Transcript.Entry]
    private let requiresCompleteAnswer: Bool

    private let responseEntryID = UUID().uuidString
    private let reasoningEntryID = UUID().uuidString
    private let toolCallsEntryID = UUID().uuidString

    /// What the answer's chunks reported about it so far.
    private(set) var facts = AnswerStream.Facts()

    /// What the provider tracks across the answer.
    private(set) var stream: Provider.Stream

    private var sentText = ""
    private var hasText = false
    private var hasReasoning = false
    private var taggedReasoning = TaggedReasoning()
    private var toolCalls = ToolCallAssembler()
    private var refusal = ""
    private var citations: [Citation] = []

    /// Starts the stream of an answer.
    ///
    /// - Parameters:
    ///   - channel: Where the answer's events go.
    ///   - provider: The service that answers.
    ///   - response: The response whose stream carries the answer.
    ///   - imageEntries: The request's entries that carry an image, which an error for an image the host rejects names.
    ///   - requiresCompleteAnswer: Whether an answer cut off at its token limit is an error, as for guided generation,
    ///     where a partial answer would decode as a wrong value.
    init(
        channel: LanguageModelExecutorGenerationChannel, provider: Provider, response: HTTPURLResponse?,
        imageEntries: [Transcript.Entry] = [], requiresCompleteAnswer: Bool = false
    ) {
        self.channel = channel
        self.provider = provider
        self.imageEntries = imageEntries
        self.requiresCompleteAnswer = requiresCompleteAnswer
        stream = provider.stream(for: response)
    }

    /// The text sent to the response entry, or empty when the answer ends in tool calls, since the round that answers
    /// them comes after.
    var responseText: String {
        toolCalls.isEmpty ? sentText : ""
    }

    /// Whether any of the answer's output has arrived: text, reasoning or a tool call.
    var hasOutput: Bool {
        hasText || hasReasoning || !toolCalls.isEmpty
    }

    /// Sends the events for one server-sent event.
    ///
    /// - Returns: Whether the event is the `[DONE]` that ends the stream.
    /// - Throws: The provider's error for an event that isn't a chunk, and for an error event.
    mutating func receive(_ event: ServerSentEvent) async throws -> Bool {
        let streamEvent: ChatCompletionChunk.StreamEvent?
        do {
            streamEvent = try ChatCompletionChunk.StreamEvent(event)
        } catch {
            throw failure(.unusableResponse(.unreadableEvent("\(error)")))
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
        let output: Provider.ChunkOutput
        do {
            output = try provider.observe(Provider.Chunk(data: data), in: &stream)
        } catch {
            throw failure(.unusableResponse(.unreadableEvent("\(error)")))
        }
        if let error = chunk.error, error != .null {
            throw failure(.errorEvent(error))
        }
        guard let delta = chunk.choices?.first?.delta else { return }

        if let reasoning = output.reasoning { await sendReasoning(reasoning) }
        if let content = delta.content, !content.isEmpty {
            await send(taggedReasoning.split(content))
        }
        if let text = delta.refusal { refusal += text }
        for annotation in delta.annotations ?? [] {
            guard let found = annotation.urlCitation, let citation = Citation(found), !citations.contains(citation) else {
                continue
            }
            citations.append(citation)
        }
        for fragment in delta.toolCalls ?? [] {
            if let arguments = toolCalls.add(fragment) {
                await channel.send(arguments.event(in: toolCallsEntryID))
            }
        }
        for generated in output.generatedData {
            await sendData(generated)
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
    ///   `GeneratedContent.ParsingError` when a guided answer reached its token limit, and the provider's error when the
    ///   stream was cut off, ended in an error, reached its token limit inside a tool call, or had a call that never
    ///   got its name.
    mutating func finish(isComplete: Bool) async throws {
        guard isComplete || facts.finishReason != nil else {
            throw failure(.unusableResponse(.cutOff))
        }
        await send(taggedReasoning.finish())
        if let error = endingError { throw error }
        let arguments: [ToolCallAssembler.Arguments]
        do {
            arguments = try toolCalls.finish()
        } catch .missingName {
            throw failure(.unusableResponse(.toolCallWithoutName))
        } catch .incompleteArguments(let toolName) {
            throw failure(.unusableResponse(.incompleteToolArguments(toolName: toolName)))
        }
        for arguments in arguments {
            await channel.send(arguments.event(in: toolCallsEntryID))
        }
        await endReasoning()
        await sendFacts()
    }

    /// The error that the answer ends in although it arrived whole: a refusal, a content filter, the host's failure,
    /// or the token limit reached inside a tool call or a guided answer. `nil` when it ended well.
    private var endingError: (any Error)? {
        let metadata = LanguageModelError.failureMetadata(status: nil, code: nil, provider: provider.facts(of: stream).host)
        if !refusal.isEmpty {
            return LanguageModelError(.refusal, message: refusal, metadata: metadata)
        }
        if facts.finishReason == .contentFilter {
            return LanguageModelError(.guardrailViolation, message: "A content filter stopped the response.", metadata: metadata)
        }
        switch facts.finishReason {
        case .error?:
            return failure(.failedAnswer)
        case .length? where !toolCalls.isEmpty:
            return failure(.unusableResponse(.tokenLimitInToolCall))
        case .length? where requiresCompleteAnswer:
            return GeneratedContent.ParsingError(
                rawContent: responseText, debugDescription: "The answer reached its token limit before it was complete.")
        default:
            return nil
        }
    }

    /// Ends the reasoning entry, when the provider has a signature for it or the model wrote a block in its answer's
    /// text: with the signature, and with the metadata that sending it back needs.
    private mutating func endReasoning() async {
        let signature = provider.facts(of: stream).reasoningSignature
        guard signature != nil || taggedReasoning.block != nil else { return }
        await sendReasoning("")
        if let signature {
            await channel.send(.reasoning(entryID: reasoningEntryID, action: .updateSignature(signature, tokenCount: 0)))
        }
        // The model may arrive after the reasoning started, and the block is known only now; replay needs both.
        await channel.send(.reasoning(entryID: reasoningEntryID, action: .updateMetadata(reasoningMetadata)))
    }

    /// Sends the answer's facts and usage on the entry that ends it: the response entry, or the tool-calls entry when
    /// tool calls end the answer.
    private func sendFacts() async {
        let providerFacts = provider.facts(of: stream)
        var metadata = facts.metadata
        metadata.merge(providerFacts.metadata) { $1 }
        let usage = facts.usage
        let usageMetadata = usage.map { $0.metadata.merging(providerFacts.usageMetadata) { $1 } }
        // Foundation Models keeps only the last request's usage on a response, so each request's usage facts also go
        // on the entry that ends it, where a response whose tool calls ran reads every request's cost.
        metadata.merge(usageMetadata ?? [:]) { $1 }
        // Citations point into the answer's text, so they go on the response entry even when tool calls end the answer.
        let citations = self.citations.isEmpty ? nil : self.citations.map(\.metadataValue)
        if toolCalls.isEmpty {
            if !hasText { await channel.send(.response(entryID: responseEntryID, action: .appendText("", tokenCount: 0))) }
            metadata[LanguageModelMetadataKey.citations] = citations
            await channel.send(.response(entryID: responseEntryID, action: .updateMetadata(metadata)))
            if let usage, let usageMetadata {
                await channel.send(
                    .response(
                        entryID: responseEntryID, action: .updateUsage(input: usage.input, output: usage.output, metadata: usageMetadata))
                )
            }
        } else {
            if hasText, let citations {
                await channel.send(
                    .response(entryID: responseEntryID, action: .updateMetadata([LanguageModelMetadataKey.citations: citations])))
            }
            // Foundation Models gives the tool-calls entry no readable metadata, so the round's facts go on its first call.
            if let first = toolCalls.firstCall {
                await channel.send(
                    .toolCalls(
                        entryID: toolCallsEntryID,
                        action: .toolCall(id: first.id, name: first.toolName, action: .updateMetadata(metadata))))
            }
            if let usage, let usageMetadata {
                await channel.send(
                    .toolCalls(
                        entryID: toolCallsEntryID, action: .updateUsage(input: usage.input, output: usage.output, metadata: usageMetadata))
                )
            }
        }
    }

    /// The reasoning entry's metadata: the provider's origin, the model that wrote it once known, and the block that
    /// opened the answer's text once the answer ended.
    private var reasoningMetadata: [String: any ConvertibleToGeneratedContent] {
        provider.reasoningOrigin.metadata(model: facts.model, taggedBlock: taggedReasoning.block)
    }

    /// The failure of the answer as the provider tracked it so far.
    private func failure(_ kind: Provider.Failure.Kind) -> any Error {
        provider.error(for: Provider.Failure(kind, stream: stream, provider: provider.name, imageEntries: imageEntries))
    }

    /// Sends a split of the answer's text: its reasoning, then its answer text.
    private mutating func send(_ split: TaggedReasoning.Split) async {
        if !split.reasoning.isEmpty { await sendReasoning(split.reasoning) }
        guard !split.text.isEmpty else { return }
        hasText = true
        sentText += split.text
        await channel.send(.response(entryID: responseEntryID, action: .appendText(split.text, tokenCount: 1)))
    }

    private mutating func sendReasoning(_ text: String) async {
        if !hasReasoning {
            hasReasoning = true
            await channel.send(.reasoning(entryID: reasoningEntryID, action: .updateMetadata(reasoningMetadata)))
        }
        guard !text.isEmpty, !hasText else { return }
        await channel.send(.reasoning(entryID: reasoningEntryID, action: .appendText(text, tokenCount: 1)))
    }

    /// Sends data the model generated as a data entry of its own.
    ///
    /// Before the OS version that has data entries, and in a build with an SDK before Xcode 27.2's, nothing is sent.
    private func sendData(_ data: Provider.ChunkOutput.GeneratedData) async {
        #if canImport(FoundationModels, _version: 2.1.14)
        guard #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *) else { return }
        await channel.send(.data(entryID: UUID().uuidString, action: .update(contentType: data.contentType, content: data.content)))
        #endif
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
