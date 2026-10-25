import Foundation
import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

/// One answer's stream: turns OpenRouter's chunks into Foundation Models channel events.
///
/// Each kind of output keeps one entry id for the whole answer, because the framework only merges events into the
/// entry they name. Reasoning text is shown until the answer's text starts. A block in `<think>` or `<thinking>` tags
/// that opens the answer's text is reasoning too, in arrival order with the rest; the reasoning entry keeps the block
/// as the model wrote it, so it goes back where the model put it. Tool-call fragments are routed by index
/// into one tool-calls entry, so parallel calls form one round. Each generated image becomes a data entry of its own.
/// The answer ends with its metadata and usage on the entry that finishes it, and with the pages it cites on its
/// response entry.
struct AnswerStream {
    private let channel: LanguageModelExecutorGenerationChannel
    private let contextSize: Int?

    private let responseEntryID = UUID().uuidString
    private let reasoningEntryID = UUID().uuidString
    private let toolCallsEntryID = UUID().uuidString

    /// What the answer's response and chunks reported about it so far.
    private(set) var facts: AnswerFacts
    private var hasText = false
    private var hasReasoning = false
    private var reasoningDetails = ReasoningDetails()
    /// Whether the model sent `reasoning_details` at all, even an empty list, which some models expect back.
    private var hasReasoningDetails = false
    private var taggedReasoning = TaggedReasoning()
    private var toolCalls = ToolCallAssembler()
    private var refusal = ""
    private var citations: [OpenRouterCitation] = []

    /// Starts the stream of an answer.
    ///
    /// - Parameters:
    ///   - channel: Where the answer's events go.
    ///   - contextSize: The smallest context size of the models the request may reach, for an oversized prompt's error.
    ///   - responseCache: What the response cache reported in the response's headers.
    init(channel: LanguageModelExecutorGenerationChannel, contextSize: Int?, responseCache: ResponseCacheStatus?) {
        self.channel = channel
        self.contextSize = contextSize
        facts = AnswerFacts(responseCache: responseCache)
    }

    /// Whether any of the answer's output has arrived: text, reasoning or a tool call.
    var hasOutput: Bool {
        hasText || hasReasoning || !toolCalls.isEmpty
    }

    /// Sends the events for one chunk.
    ///
    /// - Throws: The mapped error when the chunk reports one, with the host the chunk names.
    mutating func receive(_ chunk: ChatCompletionChunk) async throws {
        facts.update(with: chunk)
        if let error = chunk.error {
            throw OpenRouterFailure(streamError: error, provider: facts.provider).error(contextSize: contextSize)
        }
        guard let delta = chunk.choices?.first?.delta else { return }

        if let details = delta.reasoningDetails {
            hasReasoningDetails = true
            for detail in details { reasoningDetails.append(detail) }
            await sendReasoning(ReasoningDetails.readableText(in: details))
        } else if let reasoning = delta.reasoning, !reasoning.isEmpty {
            await sendReasoning(reasoning)
        }
        if let content = delta.content, !content.isEmpty {
            await send(taggedReasoning.split(content))
        }
        if let text = delta.refusal { refusal += text }
        for annotation in delta.annotations ?? [] {
            guard let found = annotation.urlCitation, let citation = OpenRouterCitation(found), !citations.contains(citation) else {
                continue
            }
            citations.append(citation)
        }
        for fragment in delta.toolCalls ?? [] {
            if let arguments = toolCalls.add(fragment) {
                await channel.send(arguments.event(in: toolCallsEntryID))
            }
        }
        for image in delta.images ?? [] {
            await sendImage(image)
        }
    }

    /// Sends the events that end the answer: arguments for calls that had none, the reasoning signature, and the
    /// metadata and usage.
    ///
    /// An answer cut off at its token limit ends like any other, with `length` as its finish reason, since Foundation
    /// Models has no error for it. One cut off inside its tool calls throws instead, so no tool gets partial arguments.
    ///
    /// - Parameter isComplete: Whether the stream ended with `[DONE]`. A stream that ends without it or a finish reason
    ///   was cut off.
    /// - Throws: `LanguageModelError.refusal` or `.guardrailViolation` when the model declined or a filter stopped it,
    ///   and `OpenRouterError` when the stream was cut off, ended in an error, reached its token limit inside a tool
    ///   call, or had a call that never got its name.
    mutating func finish(isComplete: Bool) async throws {
        guard isComplete || facts.finishReason != nil else {
            throw OpenRouterError(
                message: "The response ended before it was complete.", code: .invalidResponse, providerName: facts.provider)
        }
        await send(taggedReasoning.finish())
        if let error = endingError { throw error }
        for arguments in try toolCalls.finish(provider: facts.provider) {
            await channel.send(arguments.event(in: toolCallsEntryID))
        }
        await endReasoning()
        await sendFacts()
    }

    /// The error that the answer ends in although it arrived whole: a refusal, a content filter, a failure, or the
    /// token limit reached inside a tool call. `nil` when it ended well.
    private var endingError: (any Error)? {
        if !refusal.isEmpty {
            return LanguageModelError.refusal(.init(explanation: refusal, debugDescription: refusal))
        }
        switch facts.finishReason {
        case .contentFilter?:
            return LanguageModelError.guardrailViolation(.init(debugDescription: "A content filter stopped the response."))
        case .error?:
            return OpenRouterError(message: "The model's response ended in an error.", code: .server, providerName: facts.provider)
        case .length? where !toolCalls.isEmpty:
            return OpenRouterError(
                message: "The answer reached its token limit inside a tool call.", code: .invalidResponse,
                providerName: facts.provider)
        default:
            return nil
        }
    }

    /// Ends the reasoning entry, when the model sent reasoning details or wrote a block in its answer's text: with the
    /// details as its signature, and with the metadata that sending it back needs.
    private mutating func endReasoning() async {
        guard hasReasoningDetails || taggedReasoning.block != nil else { return }
        await sendReasoning("")
        if hasReasoningDetails {
            await channel.send(
                .reasoning(entryID: reasoningEntryID, action: .updateSignature(reasoningDetails.signature, tokenCount: 0)))
        }
        // The model may arrive after the reasoning started, and the block is known only now; replay needs both.
        await channel.send(.reasoning(entryID: reasoningEntryID, action: .updateMetadata(reasoningMetadata)))
    }

    /// Sends the answer's facts and usage on the entry that ends it: the response entry, or the tool-calls entry when
    /// tool calls end the answer.
    private func sendFacts() async {
        var metadata = facts.metadata
        // Citations point into the answer's text, so they go on the response entry even when tool calls end the answer.
        let citations = self.citations.isEmpty ? nil : self.citations.map(\.metadataValue)
        if toolCalls.isEmpty {
            if !hasText { await channel.send(.response(entryID: responseEntryID, action: .appendText("", tokenCount: 0))) }
            metadata[OpenRouterMetadataKey.citations] = citations
            await channel.send(.response(entryID: responseEntryID, action: .updateMetadata(metadata)))
            if let usage = facts.usage {
                await channel.send(
                    .response(
                        entryID: responseEntryID, action: .updateUsage(input: usage.input, output: usage.output, metadata: usage.metadata))
                )
            }
        } else {
            if hasText, let citations {
                await channel.send(
                    .response(entryID: responseEntryID, action: .updateMetadata([OpenRouterMetadataKey.citations: citations])))
            }
            await channel.send(.toolCalls(entryID: toolCallsEntryID, action: .updateMetadata(metadata)))
            if let usage = facts.usage {
                await channel.send(
                    .toolCalls(
                        entryID: toolCallsEntryID, action: .updateUsage(input: usage.input, output: usage.output, metadata: usage.metadata))
                )
            }
        }
    }

    /// The reasoning entry's metadata: the origin that marks it as OpenRouter's, the model that wrote it once known,
    /// and the block that opened the answer's text once the answer ended.
    private var reasoningMetadata: [String: any ConvertibleToGeneratedContent] {
        var metadata = ReasoningOrigin.openRouter.metadata
        metadata[OpenRouterMetadataKey.model] = facts.model
        metadata[TaggedReasoning.metadataKey] = taggedReasoning.block
        return metadata
    }

    /// Sends a split of the answer's text: its reasoning, then its answer text.
    private mutating func send(_ split: TaggedReasoning.Split) async {
        if !split.reasoning.isEmpty { await sendReasoning(split.reasoning) }
        guard !split.text.isEmpty else { return }
        hasText = true
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

    /// Sends a generated image as a data entry of its own, of the kind its data URL names.
    ///
    /// Before the OS version that has data entries, in a build with an SDK before Xcode 27.2's, and for an image that
    /// isn't inline data, such as one at a web address, nothing is sent.
    private func sendImage(_ image: ChatCompletionChunk.GeneratedImage) async {
        #if canImport(FoundationModels, _version: 2.1.14)
        guard #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *), let url = image.imageURL?.url, let inline = DataURL(url)
        else { return }
        let type = UTType(mimeType: inline.mediaType, conformingTo: .image) ?? .image
        await channel.send(.data(entryID: UUID().uuidString, action: .update(contentType: type, content: inline.data)))
        #endif
    }
}

extension OpenRouterCitation {
    /// The citation of a streamed annotation, or `nil` when it has no valid URL.
    fileprivate init?(_ citation: ChatCompletionChunk.Annotation.URLCitation) {
        guard let address = citation.url, let url = URL(string: address) else { return nil }
        self.init(url: url, title: citation.title, excerpt: citation.content, startIndex: citation.startIndex, endIndex: citation.endIndex)
    }
}
