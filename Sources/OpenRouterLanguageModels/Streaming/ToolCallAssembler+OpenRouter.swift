import LanguageModels

extension ToolCallAssembler {
    /// Adds one of OpenRouter's tool-call fragments to its call.
    mutating func add(_ fragment: ChatCompletionChunk.ToolCall) -> Arguments? {
        add(index: fragment.index, id: fragment.id, name: fragment.function?.name, arguments: fragment.function?.arguments)
    }

    /// Ends the calls.
    ///
    /// - Throws: `OpenRouterError` when a call never got its name.
    func finish(provider: OpenRouterProviderName?) throws -> [Arguments] {
        guard let arguments = finish() else {
            throw OpenRouterError(message: "The model sent a tool call without its name.", code: .invalidResponse, providerName: provider)
        }
        return arguments
    }
}
