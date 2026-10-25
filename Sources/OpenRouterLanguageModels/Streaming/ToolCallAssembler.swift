import Foundation
import FoundationModels

/// An answer's tool calls, assembled from their fragments as they arrive.
///
/// Fragments are routed by index, so parallel calls form one round. A fragment without an index continues the last
/// call, unless it brings a new id, which starts the next call. A call starts once it has a name, with an id made up if
/// the model sent none or one another call already uses, so the calls keep their order and none replaces another.
/// Argument text that arrives before the name is held until the call starts.
struct ToolCallAssembler {
    private var calls: [Int: Call] = [:]
    private var lastIndex: Int?

    /// Whether no fragment has arrived.
    var isEmpty: Bool {
        calls.isEmpty
    }

    /// Adds one fragment to its call.
    ///
    /// - Returns: The text to append to the call's arguments: all of it so far when the fragment starts the call, even
    ///   none, which announces the call; otherwise the fragment's own. `nil` when the call hasn't started or the
    ///   fragment has no text.
    mutating func add(_ fragment: ChatCompletionChunk.ToolCall) -> Arguments? {
        let index = index(of: fragment)
        lastIndex = index
        var call = calls[index] ?? Call()
        let wasStarted = call.id != nil && call.name != nil
        if call.id == nil, let id = fragment.id, !id.isEmpty, !calls.values.contains(where: { $0.id == id }) { call.id = id }
        if call.name == nil, let name = fragment.function?.name, !name.isEmpty { call.name = name }
        if call.name != nil, call.id == nil { call.id = "call_\(UUID().uuidString)" }
        call.pendingArguments += fragment.function?.arguments ?? ""
        var arguments: Arguments?
        if let id = call.id, let name = call.name, !wasStarted || !call.pendingArguments.isEmpty {
            arguments = Arguments(callID: id, toolName: name, text: call.pendingArguments)
            call.hasArguments = call.hasArguments || !call.pendingArguments.isEmpty
            call.pendingArguments = ""
        }
        calls[index] = call
        return arguments
    }

    /// Ends the calls.
    ///
    /// - Parameter provider: The host that served the answer, for the error.
    /// - Returns: An empty JSON object, in index order, as the arguments of each call that got none, since a call to a
    ///   tool without arguments may send none, and Foundation Models parses them as JSON.
    /// - Throws: `OpenRouterError` when a call never got its name.
    func finish(provider: OpenRouterProviderName?) throws -> [Arguments] {
        try calls.sorted { $0.key < $1.key }.compactMap { _, call in
            guard let id = call.id, let name = call.name else {
                throw OpenRouterError(
                    message: "The model sent a tool call without its name.", code: .invalidResponse, providerName: provider)
            }
            return call.hasArguments ? nil : Arguments(callID: id, toolName: name, text: "{}")
        }
    }

    /// The index of the call a fragment belongs to.
    private func index(of fragment: ChatCompletionChunk.ToolCall) -> Int {
        if let index = fragment.index { return index }
        guard let last = lastIndex else { return 0 }
        guard let id = fragment.id, !id.isEmpty, let lastID = calls[last]?.id, id != lastID else { return last }
        return (calls.keys.max() ?? last) + 1
    }
}

extension ToolCallAssembler {
    /// Text to append to the arguments of a started call.
    struct Arguments: Equatable {
        let callID: String
        let toolName: String
        let text: String

        /// The event that appends the text to the call in the answer's tool-calls entry.
        func event(in entryID: String) -> LanguageModelExecutorGenerationChannel.Event {
            .toolCalls(
                entryID: entryID,
                action: .toolCall(id: callID, name: toolName, action: .appendArguments(text, tokenCount: text.isEmpty ? 0 : 1))
            )
        }
    }

    /// One call as its fragments arrive.
    private struct Call {
        var id: String?
        var name: String?
        /// Argument text that arrived before the call's name, held until the call can start.
        var pendingArguments = ""
        var hasArguments = false
    }
}
