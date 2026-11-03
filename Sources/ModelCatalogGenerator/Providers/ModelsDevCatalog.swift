import Foundation

/// The models.dev catalog, reduced to OpenAI's models and the facts the catalog reads about them: what each takes and
/// does, which OpenAI's own model list doesn't say.
struct ModelsDevCatalog: Decodable {
    /// One of OpenAI's models.
    struct Model: Decodable {
        struct Modalities: Decodable {
            let input: [String]
            let output: [String]
        }

        struct Limit: Decodable {
            let context: Int?
        }

        /// A way a request can set the model's reasoning, such as its `effort`, with the values it takes.
        struct ReasoningOption: Decodable {
            let type: String
            let values: [String]?
        }

        let name: String
        /// The kind of model, such as `image` or `embedding`, or `nil` for a model that generates text.
        let type: String?
        let reasoning: Bool?
        let reasoningOptions: [ReasoningOption]?
        let toolCall: Bool?
        let structuredOutput: Bool?
        let temperature: Bool?
        /// The month or day the training data ends, as `yyyy-MM` or `yyyy-MM-dd`.
        let knowledge: String?
        let modalities: Modalities
        let limit: Limit?

        private enum CodingKeys: String, CodingKey {
            case name, type, reasoning, temperature, knowledge, modalities, limit
            case reasoningOptions = "reasoning_options"
            case toolCall = "tool_call"
            case structuredOutput = "structured_output"
        }

        /// The effort words the model takes, in the catalog's order.
        var efforts: [String] {
            reasoningOptions?.first { $0.type == ModelsDevCatalog.effortOption }?.values ?? []
        }
    }

    private struct Provider: Decodable {
        let models: [String: Model]
    }

    /// The kind of reasoning option that lists the efforts.
    private static let effortOption = "effort"

    /// The provider's key in the catalog.
    static let providerKey = "openai"

    /// OpenAI's models, by id.
    let models: [String: Model]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: JSONKey.self)
        models = try container.decode(Provider.self, forKey: JSONKey(stringValue: Self.providerKey)).models
    }

    static func decoded(from data: Data) throws -> ModelsDevCatalog {
        try JSONDecoder().decode(ModelsDevCatalog.self, from: data)
    }

    /// OpenAI's part of the catalog as a JSON document whose models are a list, so its shape doesn't name each model's
    /// id: `{"models": [...]}`.
    ///
    /// - Throws: An error when `data` isn't the catalog.
    static func shapeDocument(of data: Data) throws -> Data {
        guard let catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let provider = catalog[providerKey] as? [String: Any], let models = provider["models"] as? [String: Any]
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "It has no \(providerKey) models."))
        }
        let sorted = models.sorted { $0.key < $1.key }.map(\.value)
        return try JSONSerialization.data(withJSONObject: ["models": sorted], options: [.sortedKeys])
    }
}

/// A JSON key named at run time.
private struct JSONKey: CodingKey {
    let stringValue: String

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int? { nil }

    init?(intValue: Int) {
        nil
    }
}
