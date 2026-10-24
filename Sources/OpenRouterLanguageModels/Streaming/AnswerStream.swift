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

    private let responseID = UUID().uuidString
    private let reasoningID = UUID().uuidString
    private let toolCallsID = UUID().uuidString

    private var hasText = false
    private var hasReasoning = false
    private var reasoningDetails = ReasoningDetails()
    /// Whether the model sent `reasoning_details` at all, even an empty list, which some models expect back.
    private var hasReasoningDetails = false
    private var taggedReasoning = TaggedReasoning()
    private var toolCalls: [Int: ToolCall] = [:]
    private var lastToolCallIndex: Int?
    private var refusal = ""
    private var citations: [OpenRouterCitation] = []
    private var finishReason: OpenRouterFinishReason?
    private var usage: ChatCompletionChunk.Usage?
    private var model: String?
    private var provider: OpenRouterProviderName?
    private var generationID: String?
    private var serviceTier: OpenRouterServiceTier?
    private var routerMetadata: ChatCompletionChunk.RouterMetadata?
    private var responseCache: ResponseCacheStatus?

    init(channel: LanguageModelExecutorGenerationChannel, contextSize: Int?) {
        self.channel = channel
        self.contextSize = contextSize
    }

    /// Reads what the response's headers say about the answer: whether the response cache served it.
    mutating func receive(_ response: HTTPURLResponse?) {
        responseCache = ResponseCacheStatus(response)
    }

    /// Sends the events for one chunk.
    ///
    /// - Throws: The mapped error when the chunk reports one, with the host the chunk names.
    mutating func receive(_ chunk: ChatCompletionChunk) async throws {
        generationID = chunk.id ?? generationID
        model = chunk.model ?? model
        provider = chunk.provider.map(OpenRouterProviderName.init) ?? provider
        serviceTier = chunk.serviceTier ?? serviceTier
        usage = chunk.usage ?? usage
        routerMetadata = chunk.routerMetadata ?? routerMetadata
        if let error = chunk.error {
            throw OpenRouterFailure(streamError: error, provider: provider).error(contextSize: contextSize)
        }
        guard let choice = chunk.choices?.first else { return }
        finishReason = choice.finishReason ?? finishReason
        guard let delta = choice.delta else { return }

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
            guard let citation = annotation.urlCitation.flatMap({ OpenRouterCitation($0) }), !citations.contains(citation) else {
                continue
            }
            citations.append(citation)
        }
        for fragment in delta.toolCalls ?? [] {
            await receive(fragment)
        }
        for image in delta.images ?? [] {
            await receive(image)
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
        guard isComplete || finishReason != nil else {
            throw OpenRouterError(message: "The response ended before it was complete.", code: .invalidResponse, providerName: provider)
        }
        await send(taggedReasoning.finish())
        if !refusal.isEmpty {
            throw LanguageModelError.refusal(.init(explanation: refusal, debugDescription: refusal))
        }
        switch finishReason {
        case .contentFilter?:
            throw LanguageModelError.guardrailViolation(.init(debugDescription: "A content filter stopped the response."))
        case .error?:
            throw OpenRouterError(message: "The model's response ended in an error.", code: .server, providerName: provider)
        case .length? where !toolCalls.isEmpty:
            throw OpenRouterError(
                message: "The answer reached its token limit inside a tool call.", code: .invalidResponse, providerName: provider)
        default:
            break
        }
        for index in toolCalls.keys.sorted() {
            guard let call = toolCalls[index], call.isStarted else {
                throw OpenRouterError(
                    message: "The model sent a tool call without its name.", code: .invalidResponse, providerName: provider)
            }
            if !call.hasArguments {
                // A call to a tool without arguments may send none, and Foundation Models parses them as JSON.
                await channel.send(call.event(appending: "{}", in: toolCallsID))
            }
        }
        if hasReasoningDetails || taggedReasoning.block != nil {
            await sendReasoning("")
            if hasReasoningDetails {
                await channel.send(
                    .reasoning(entryID: reasoningID, action: .updateSignature(reasoningDetails.signature, tokenCount: 0)))
            }
            // The model may arrive after the reasoning started, and the block is known only now; replay needs both.
            await channel.send(.reasoning(entryID: reasoningID, action: .updateMetadata(reasoningMetadata)))
        }

        var metadata: [String: any ConvertibleToGeneratedContent] = [:]
        metadata[OpenRouterMetadataKey.model] = model
        metadata[OpenRouterMetadataKey.provider] = provider?.rawValue
        metadata[OpenRouterMetadataKey.responseID] = generationID
        metadata[OpenRouterMetadataKey.finishReason] = finishReason?.rawValue
        metadata[OpenRouterMetadataKey.serviceTier] = serviceTier?.rawValue
        metadata.merge(responseCache?.metadata ?? [:]) { $1 }
        metadata.merge(routerMetadata?.metadata ?? [:]) { $1 }
        let usage = self.usage.map(UsageTotals.init)
        // Citations point into the answer's text, so they go on the response entry even when tool calls end the answer.
        let citations = self.citations.isEmpty ? nil : self.citations.map(\.metadataValue)
        if toolCalls.isEmpty {
            if !hasText { await channel.send(.response(entryID: responseID, action: .appendText("", tokenCount: 0))) }
            metadata[OpenRouterMetadataKey.citations] = citations
            await channel.send(.response(entryID: responseID, action: .updateMetadata(metadata)))
            if let usage {
                await channel.send(
                    .response(entryID: responseID, action: .updateUsage(input: usage.input, output: usage.output, metadata: usage.metadata))
                )
            }
        } else {
            if hasText, let citations {
                await channel.send(.response(entryID: responseID, action: .updateMetadata([OpenRouterMetadataKey.citations: citations])))
            }
            await channel.send(.toolCalls(entryID: toolCallsID, action: .updateMetadata(metadata)))
            if let usage {
                await channel.send(
                    .toolCalls(
                        entryID: toolCallsID, action: .updateUsage(input: usage.input, output: usage.output, metadata: usage.metadata))
                )
            }
        }
    }

    /// The reasoning entry's metadata: the origin that marks it as OpenRouter's, the model that wrote it once known,
    /// and the block that opened the answer's text once the answer ended.
    private var reasoningMetadata: [String: any ConvertibleToGeneratedContent] {
        var metadata = ReasoningOrigin.openRouter.metadata
        metadata[OpenRouterMetadataKey.model] = model
        metadata[TaggedReasoning.metadataKey] = taggedReasoning.block
        return metadata
    }

    /// Sends a split of the answer's text: its reasoning, then its answer text.
    private mutating func send(_ split: TaggedReasoning.Split) async {
        if !split.reasoning.isEmpty { await sendReasoning(split.reasoning) }
        guard !split.text.isEmpty else { return }
        hasText = true
        await channel.send(.response(entryID: responseID, action: .appendText(split.text, tokenCount: 1)))
    }

    private mutating func sendReasoning(_ text: String) async {
        if !hasReasoning {
            hasReasoning = true
            await channel.send(.reasoning(entryID: reasoningID, action: .updateMetadata(reasoningMetadata)))
        }
        guard !text.isEmpty, !hasText else { return }
        await channel.send(.reasoning(entryID: reasoningID, action: .appendText(text, tokenCount: 1)))
    }

    /// Routes one tool-call fragment by its index. A call starts once it has a name, with an id made up if the model
    /// sent none or one another call already uses, so the calls keep their order and none replaces another; argument
    /// text that came earlier follows then.
    private mutating func receive(_ fragment: ChatCompletionChunk.ToolCall) async {
        let index = self.index(of: fragment)
        lastToolCallIndex = index
        var call = toolCalls[index] ?? ToolCall()
        let wasStarted = call.isStarted
        if call.id == nil, let id = fragment.id, !id.isEmpty, !toolCalls.values.contains(where: { $0.id == id }) { call.id = id }
        if call.name == nil, let name = fragment.function?.name, !name.isEmpty { call.name = name }
        if call.name != nil, call.id == nil { call.id = "call_\(UUID().uuidString)" }
        call.pendingArguments += fragment.function?.arguments ?? ""
        if call.isStarted, !wasStarted || !call.pendingArguments.isEmpty {
            await channel.send(call.event(appending: call.pendingArguments, in: toolCallsID))
            call.hasArguments = call.hasArguments || !call.pendingArguments.isEmpty
            call.pendingArguments = ""
        }
        toolCalls[index] = call
    }

    /// Sends a generated image as a data entry of its own, of the kind its data URL names.
    ///
    /// Before the OS version that has data entries, in a build with an SDK before Xcode 27.2's, and for an image that
    /// isn't inline data, such as one at a web address, nothing is sent.
    private func receive(_ image: ChatCompletionChunk.GeneratedImage) async {
        #if canImport(FoundationModels, _version: 2.1.14)
        guard #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *), let url = image.imageURL?.url, let inline = DataURL(url)
        else { return }
        let type = UTType(mimeType: inline.mediaType, conformingTo: .image) ?? .image
        await channel.send(.data(entryID: UUID().uuidString, action: .update(contentType: type, content: inline.data)))
        #endif
    }

    /// The index of the call a fragment belongs to. A fragment without one continues the last call, unless it brings
    /// a new id, which starts the next call.
    private func index(of fragment: ChatCompletionChunk.ToolCall) -> Int {
        if let index = fragment.index { return index }
        guard let last = lastToolCallIndex else { return 0 }
        guard let id = fragment.id, !id.isEmpty, let lastID = toolCalls[last]?.id, id != lastID else { return last }
        return (toolCalls.keys.max() ?? last) + 1
    }
}

/// The usage OpenRouter reported, as Foundation Models' running totals, with the cost, its parts and the server tools'
/// counts in the metadata.
private struct UsageTotals {
    let input: LanguageModelExecutorGenerationChannel.Usage.Input
    let output: LanguageModelExecutorGenerationChannel.Usage.Output
    let metadata: [String: any ConvertibleToGeneratedContent]

    init(_ usage: ChatCompletionChunk.Usage) {
        input = .init(totalTokenCount: usage.promptTokens ?? 0, cachedTokenCount: usage.promptTokensDetails?.cachedTokens ?? 0)
        output = .init(
            totalTokenCount: usage.completionTokens ?? 0,
            reasoningTokenCount: usage.completionTokensDetails?.reasoningTokens ?? 0
        )
        var metadata: [String: any ConvertibleToGeneratedContent] = [:]
        metadata[OpenRouterMetadataKey.cost] = usage.cost
        metadata[OpenRouterMetadataKey.cacheWriteTokenCount] = usage.promptTokensDetails?.cacheWriteTokens
        metadata[OpenRouterMetadataKey.isBYOK] = usage.isBYOK
        let costs = usage.costDetails
        metadata[OpenRouterMetadataKey.upstreamInferenceCost] = costs?.upstreamInferenceCost
        metadata[OpenRouterMetadataKey.upstreamInferencePromptCost] = costs?.upstreamInferencePromptCost
        metadata[OpenRouterMetadataKey.upstreamInferenceCompletionCost] = costs?.upstreamInferenceCompletionsCost
        metadata[OpenRouterMetadataKey.serverToolCost] = costs?.serverToolCost
        let serverTools = usage.serverToolUseDetails
        metadata[OpenRouterMetadataKey.requestedServerToolCallCount] = serverTools?.toolCallsRequested
        metadata[OpenRouterMetadataKey.executedServerToolCallCount] = serverTools?.toolCallsExecuted
        metadata[OpenRouterMetadataKey.webSearchCount] = serverTools?.webSearchRequests
        self.metadata = metadata
    }
}

extension ChatCompletionChunk.RouterMetadata {
    /// The router's report as metadata of the entry that ends the answer, with the generation time in seconds.
    fileprivate var metadata: [String: any ConvertibleToGeneratedContent] {
        var metadata: [String: any ConvertibleToGeneratedContent] = [:]
        metadata[OpenRouterMetadataKey.routingStrategy] = strategy
        metadata[OpenRouterMetadataKey.routingAttempt] = attempt
        metadata[OpenRouterMetadataKey.routingAttempts] = attempts?.map { attempt in
            GeneratedContent(properties: ["provider": attempt.provider, "model": attempt.model, "status": attempt.status])
        }
        metadata[OpenRouterMetadataKey.routingEndpoints] = endpoints?.available?.map { endpoint in
            GeneratedContent(properties: ["provider": endpoint.provider, "model": endpoint.model, "selected": endpoint.selected])
        }
        metadata[OpenRouterMetadataKey.routingPipeline] = pipeline?.map { stage in
            GeneratedContent(properties: ["type": stage.type, "name": stage.name, "summary": stage.summary])
        }
        metadata[OpenRouterMetadataKey.region] = region
        metadata[OpenRouterMetadataKey.generationTime] = generationTime.map { $0 / 1_000 }
        return metadata
    }
}

extension OpenRouterCitation {
    /// The citation of a streamed annotation, or `nil` when it has no valid URL.
    fileprivate init?(_ citation: ChatCompletionChunk.Annotation.URLCitation) {
        guard let address = citation.url, let url = URL(string: address) else { return nil }
        self.init(url: url, title: citation.title, excerpt: citation.content, startIndex: citation.startIndex, endIndex: citation.endIndex)
    }
}

/// One tool call as its fragments arrive.
private struct ToolCall {
    var id: String?
    var name: String?
    /// Argument text that arrived before the call's name, held until the call can start.
    var pendingArguments = ""
    var hasArguments = false

    var isStarted: Bool { id != nil && name != nil }

    func event(appending arguments: String, in entryID: String) -> LanguageModelExecutorGenerationChannel.Event {
        .toolCalls(
            entryID: entryID,
            action: .toolCall(id: id ?? "", name: name ?? "", action: .appendArguments(arguments, tokenCount: arguments.isEmpty ? 0 : 1))
        )
    }
}
