import APIFormat

@testable import ChatCompletionsAPI

extension ToolCallAssembler {
    /// Adds one of a chunk's tool-call fragments to its call, as the format's stream routes it.
    mutating func add(_ fragment: ChatCompletionChunk.ToolCall) -> Arguments? {
        add(index: fragment.index, id: fragment.id, name: fragment.function?.name, arguments: fragment.function?.arguments)
    }
}
