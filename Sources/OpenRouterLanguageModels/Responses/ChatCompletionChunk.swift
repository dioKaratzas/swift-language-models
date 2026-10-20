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
        let annotations: [Annotation]?

        private enum CodingKeys: String, CodingKey {
            case content
            case reasoning
            case reasoningDetails = "reasoning_details"
            case refusal
            case toolCalls = "tool_calls"
            case annotations
        }
    }

    /// A note on the answer's text, of which only URL citations are read. Other kinds, such as file annotations, have
    /// none.
    struct Annotation: Decodable {
        /// A web page the text cites. Hosts may leave out any field, so each is optional.
        struct URLCitation: Decodable {
            let url: String?
            let title: String?
            let content: String?
            let startIndex: Int?
            let endIndex: Int?

            private enum CodingKeys: String, CodingKey {
                case url
                case title
                case content
                case startIndex = "start_index"
                case endIndex = "end_index"
            }
        }

        let urlCitation: URLCitation?

        private enum CodingKeys: String, CodingKey {
            case urlCitation = "url_citation"
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

        /// The parts of the cost, in US dollars.
        struct CostDetails: Decodable {
            let upstreamInferenceCost: Double?
            let upstreamInferencePromptCost: Double?
            let upstreamInferenceCompletionsCost: Double?
            let serverToolCost: Double?

            private enum CodingKeys: String, CodingKey {
                case upstreamInferenceCost = "upstream_inference_cost"
                case upstreamInferencePromptCost = "upstream_inference_prompt_cost"
                case upstreamInferenceCompletionsCost = "upstream_inference_completions_cost"
                case serverToolCost = "server_tool_cost"
            }
        }

        /// How often the server tools ran.
        struct ServerToolUseDetails: Decodable {
            let toolCallsRequested: Int?
            let toolCallsExecuted: Int?
            let webSearchRequests: Int?

            private enum CodingKeys: String, CodingKey {
                case toolCallsRequested = "tool_calls_requested"
                case toolCallsExecuted = "tool_calls_executed"
                case webSearchRequests = "web_search_requests"
            }
        }

        let promptTokens: Int?
        let completionTokens: Int?
        let promptTokensDetails: PromptDetails?
        let completionTokensDetails: CompletionDetails?
        let cost: Double?
        let costDetails: CostDetails?
        let isBYOK: Bool?
        let serverToolUseDetails: ServerToolUseDetails?

        private enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case promptTokensDetails = "prompt_tokens_details"
            case completionTokensDetails = "completion_tokens_details"
            case cost
            case costDetails = "cost_details"
            case isBYOK = "is_byok"
            case serverToolUseDetails = "server_tool_use_details"
        }
    }

    /// What OpenRouter's router did for the request, on the last chunk of a request that asks for it. Every field is
    /// optional, since OpenRouter adds fields over time and leaves some out.
    struct RouterMetadata: Decodable {
        struct Endpoints: Decodable {
            struct Endpoint: Decodable {
                let provider: String?
                let model: String?
                let selected: Bool?
            }

            let available: [Endpoint]?
        }

        struct Attempt: Decodable {
            let provider: String?
            let model: String?
            let status: Int?
        }

        /// A plugin that changed the request or the answer. Its free-form `data` isn't read.
        struct Stage: Decodable {
            let type: String?
            let name: String?
            let summary: String?
        }

        let strategy: String?
        let attempt: Int?
        let attempts: [Attempt]?
        let endpoints: Endpoints?
        /// The milliseconds from sending the request to the host until its answer ended.
        let generationTime: Double?
        let region: String?
        let pipeline: [Stage]?

        private enum CodingKeys: String, CodingKey {
            case strategy
            case attempt
            case attempts
            case endpoints
            case generationTime = "generation_time"
            case region
            case pipeline
        }
    }

    let id: String?
    let model: String?
    let provider: String?
    let serviceTier: OpenRouterServiceTier?
    let choices: [Choice]?
    let usage: Usage?
    let routerMetadata: RouterMetadata?
    let error: OpenRouterErrorResponse?

    private enum CodingKeys: String, CodingKey {
        case id
        case model
        case provider
        case serviceTier = "service_tier"
        case choices
        case usage
        case routerMetadata = "openrouter_metadata"
        case error
    }

    static func decoded(from data: Data) throws -> ChatCompletionChunk {
        try JSONDecoder().decode(ChatCompletionChunk.self, from: data)
    }
}
