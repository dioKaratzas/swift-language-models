import Foundation

/// The body of OpenRouter's `GET /models`, reduced to the fields the catalog uses.
///
/// Days decode into their type, so a fetch fails on one that isn't real instead of storing it.
struct OpenRouterModelsResponse: Decodable {
    struct Model: Decodable {
        struct AliasTarget: Decodable {
            let slug: String
        }

        struct Architecture: Decodable {
            let inputModalities: [String]
            let outputModalities: [String]
        }

        struct TopProvider: Decodable {
            let maxCompletionTokens: Int?
        }

        struct Reasoning: Decodable {
            /// The efforts a model accepts, as OpenRouter reports them.
            enum Efforts: Equatable {
                /// The model leaves `supported_efforts` out, so its effort can't be chosen.
                case unlisted
                /// The model sends `null`, so it accepts every effort.
                case any
                /// The words the model lists, in its order, each once.
                case listed([String])
            }

            let supportedEfforts: Efforts
            let defaultEffort: String?
            let mandatory: Bool?
            let defaultEnabled: Bool?

            private enum CodingKeys: String, CodingKey {
                case supportedEfforts
                case defaultEffort
                case mandatory
                case defaultEnabled
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                supportedEfforts =
                    if !container.contains(.supportedEfforts) {
                        .unlisted
                    } else if try container.decodeNil(forKey: .supportedEfforts) {
                        .any
                    } else {
                        .listed(try container.decode([String?].self, forKey: .supportedEfforts).compactMap(\.self).uniqued())
                    }
                defaultEffort = try container.decodeIfPresent(String.self, forKey: .defaultEffort)
                mandatory = try container.decodeIfPresent(Bool.self, forKey: .mandatory)
                defaultEnabled = try container.decodeIfPresent(Bool.self, forKey: .defaultEnabled)
            }
        }

        struct Pricing: Decodable {
            let inputCacheWrite: String?
        }

        let id: String
        let name: String
        let aliasTarget: AliasTarget?
        let created: Int
        let knowledgeCutoff: CatalogDay?
        let expirationDate: CatalogDay?
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
