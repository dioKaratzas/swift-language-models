import LanguageModels

extension ToolCallAssembler {
    /// Adds one of OpenRouter's tool-call fragments to its call.
    mutating func add(_ fragment: ChatCompletionChunk.ToolCall) -> Arguments? {
        add(index: fragment.index, id: fragment.id, name: fragment.function?.name, arguments: fragment.function?.arguments)
    }

    /// Ends the calls.
    ///
    /// - Throws: `OpenRouterError` with `invalidResponse` when a call never got its name, or its arguments aren't a whole
    ///   JSON object.
    func finish(provider: OpenRouterProviderName?) throws -> [Arguments] {
        do {
            return try finish()
        } catch .missingName {
            throw OpenRouterError(message: "The model sent a tool call without its name.", code: .invalidResponse, providerName: provider)
        } catch .incompleteArguments(let toolName) {
            throw OpenRouterError(
                message: "The model sent arguments for \(toolName) that aren't a whole JSON object.", code: .invalidResponse,
                providerName: provider)
        }
    }
}
