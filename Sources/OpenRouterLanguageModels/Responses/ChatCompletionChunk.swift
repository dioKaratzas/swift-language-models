import Foundation
import LanguageModels

/// One event of OpenRouter's streamed chat completion, reduced to the fields the executor reads.
///
/// Keys are listed one by one instead of converted from snake case, because a conversion would also rename the keys
/// inside `reasoning_details`, which go back to OpenRouter unchanged.
struct ChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        let delta: Delta?
        let finishReason: FinishReason?

        private enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Delta: Decodable {
        let content: String?
        let reasoning: String?
        let reasoningDetails: [JSONValue]?
        let refusal: String?
        let toolCalls: [ToolCall]?

        private enum CodingKeys: String, CodingKey {
            case content
            case reasoning
            case reasoningDetails = "reasoning_details"
            case refusal
            case toolCalls = "tool_calls"
        }
    }

    /// A fragment of one tool call. The first fragment of a call carries its id and name, later ones only argument
    /// text.
    struct ToolCall: Decodable {
        struct Function: Decodable {
            let name: String?
            let arguments: String?
        }

        let index: Int?
        let id: String?
        let function: Function?
    }

    struct Usage: Decodable {
        struct PromptDetails: Decodable {
            let cachedTokens: Int?
            let cacheWriteTokens: Int?

            private enum CodingKeys: String, CodingKey {
                case cachedTokens = "cached_tokens"
                case cacheWriteTokens = "cache_write_tokens"
            }
        }

        struct CompletionDetails: Decodable {
            let reasoningTokens: Int?

            private enum CodingKeys: String, CodingKey {
                case reasoningTokens = "reasoning_tokens"
            }
        }

        let promptTokens: Int?
        let completionTokens: Int?
        let promptTokensDetails: PromptDetails?
        let completionTokensDetails: CompletionDetails?
        let cost: Double?

        private enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case promptTokensDetails = "prompt_tokens_details"
            case completionTokensDetails = "completion_tokens_details"
            case cost
        }
    }

    let id: String?
    let model: String?
    let provider: String?
    let choices: [Choice]?
    let usage: Usage?
    let error: OpenRouterErrorBody?

    static func decoded(from data: Data) throws -> ChatCompletionChunk {
        try JSONDecoder().decode(ChatCompletionChunk.self, from: data)
    }
}
