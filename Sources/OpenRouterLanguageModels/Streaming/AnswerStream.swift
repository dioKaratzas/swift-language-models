import Foundation
import FoundationModels
import LanguageModels

/// One answer's stream: turns OpenRouter's chunks into Foundation Models channel events.
///
/// Each kind of output keeps one entry id for the whole answer, because the framework only merges events into the
/// entry they name. Reasoning text is shown until the answer's text starts. Tool-call fragments are routed by index
/// into one tool-calls entry, so parallel calls form one round. The answer ends with its metadata and usage on the
/// entry that finishes it.
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
    private var toolCalls: [Int: ToolCall] = [:]
    private var lastToolCallIndex: Int?
    private var refusal = ""
    private var finishReason: FinishReason?
    private var usage: ChatCompletionChunk.Usage?
    private var model: String?
    private var provider: OpenRouterProviderName?
    private var generationID: String?

    init(channel: LanguageModelExecutorGenerationChannel, contextSize: Int?) {
        self.channel = channel
        self.contextSize = contextSize
    }

    /// Sends the events for one chunk.
    ///
    /// - Throws: The mapped error when the chunk reports one.
    mutating func receive(_ chunk: ChatCompletionChunk) async throws {
        if let error = chunk.error {
            throw OpenRouterFailure(streamError: error).error(contextSize: contextSize)
        }
        generationID = chunk.id ?? generationID
        model = chunk.model ?? model
        provider = chunk.provider.map(OpenRouterProviderName.init) ?? provider
        usage = chunk.usage ?? usage
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
            hasText = true
            await channel.send(.response(entryID: responseID, action: .appendText(content, tokenCount: 1)))
        }
        if let text = delta.refusal { refusal += text }
        for fragment in delta.toolCalls ?? [] {
            await receive(fragment)
        }
    }

    /// Sends the events that end the answer: arguments for calls that had none, the reasoning signature, and the
    /// metadata and usage.
    ///
    /// An answer cut off at its token limit ends like any other, with `length` as its finish reason, since Foundation
    /// Models has no error for it.
    ///
    /// - Parameter isComplete: Whether the stream ended with `[DONE]`. A stream that ends without it or a finish reason
    ///   was cut off.
    /// - Throws: `LanguageModelError.refusal` or `.guardrailViolation` when the model declined or a filter stopped it,
    ///   and `OpenRouterError` when the stream was cut off, ended in an error, or had a call that never got its name.
    mutating func finish(isComplete: Bool) async throws {
        guard isComplete || finishReason != nil else {
            throw OpenRouterError(message: "The response ended before it was complete.", code: .invalidResponse, providerName: provider)
        }
        if !refusal.isEmpty {
            throw LanguageModelError.refusal(.init(explanation: refusal, debugDescription: refusal))
        }
        switch finishReason {
        case .contentFilter?:
            throw LanguageModelError.guardrailViolation(.init(debugDescription: "A content filter stopped the response."))
        case .error?:
            throw OpenRouterError(message: "The model's response ended in an error.", code: .server, providerName: provider)
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
        if hasReasoningDetails {
            await sendReasoning("")
            await channel.send(.reasoning(entryID: reasoningID, action: .updateSignature(reasoningDetails.signature, tokenCount: 0)))
            // The model may arrive after the reasoning started, and replay needs it.
            await channel.send(.reasoning(entryID: reasoningID, action: .updateMetadata(reasoningMetadata)))
        }

        var metadata: [String: any ConvertibleToGeneratedContent] = [:]
        metadata[OpenRouterMetadataKey.model] = model
        metadata[OpenRouterMetadataKey.provider] = provider?.rawValue
        metadata[OpenRouterMetadataKey.generationID] = generationID
        metadata[OpenRouterMetadataKey.finishReason] = finishReason?.rawValue
        let usage = self.usage.map(UsageTotals.init)
        if toolCalls.isEmpty {
            if !hasText { await channel.send(.response(entryID: responseID, action: .appendText("", tokenCount: 0))) }
            await channel.send(.response(entryID: responseID, action: .updateMetadata(metadata)))
            if let usage {
                await channel.send(
                    .response(entryID: responseID, action: .updateUsage(input: usage.input, output: usage.output, metadata: usage.metadata))
                )
            }
        } else {
            await channel.send(.toolCalls(entryID: toolCallsID, action: .updateMetadata(metadata)))
            if let usage {
                await channel.send(
                    .toolCalls(
                        entryID: toolCallsID, action: .updateUsage(input: usage.input, output: usage.output, metadata: usage.metadata))
                )
            }
        }
    }

    /// The reasoning entry's metadata: the tag that marks it as OpenRouter's, and the model that wrote it once known.
    private var reasoningMetadata: [String: any ConvertibleToGeneratedContent] {
        var metadata: [String: any ConvertibleToGeneratedContent] = [ReasoningDetails.metadataKey: ReasoningDetails.metadataValue]
        metadata[OpenRouterMetadataKey.model] = model
        return metadata
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

    /// The index of the call a fragment belongs to. A fragment without one continues the last call, unless it brings
    /// a new id, which starts the next call.
    private func index(of fragment: ChatCompletionChunk.ToolCall) -> Int {
        if let index = fragment.index { return index }
        guard let last = lastToolCallIndex else { return 0 }
        guard let id = fragment.id, !id.isEmpty, let lastID = toolCalls[last]?.id, id != lastID else { return last }
        return (toolCalls.keys.max() ?? last) + 1
    }
}

/// The usage OpenRouter reported, as Foundation Models' running totals, with the cost in the metadata.
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
        self.metadata = metadata
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
