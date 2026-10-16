import Foundation

/// The body of OpenRouter's `GET /models`, reduced to the fields the catalog uses.
struct OpenRouterModelsResponse: Decodable {
    struct Model: Decodable {
        struct Architecture: Decodable {
            let inputModalities: [String]
        }

        struct TopProvider: Decodable {
            let maxCompletionTokens: Int?
        }

        struct Reasoning: Decodable {
            let supportedEfforts: [String]?
            let defaultEffort: String?
        }

        struct Pricing: Decodable {
            let prompt: String
            let completion: String
        }

        let id: String
        let name: String
        let contextLength: Int?
        let architecture: Architecture
        let topProvider: TopProvider?
        let supportedParameters: [String]?
        let reasoning: Reasoning?
        let pricing: Pricing?
    }

    let data: [Model]

    static func decoded(from data: Data) throws -> OpenRouterModelsResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(OpenRouterModelsResponse.self, from: data)
    }
}
