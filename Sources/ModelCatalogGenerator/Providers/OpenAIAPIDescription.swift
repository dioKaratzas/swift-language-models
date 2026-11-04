/// OpenAI's OpenAPI description, reduced to what the catalog reads: the ids of the models its text APIs list, and the
/// effort words.
struct OpenAIAPIDescription: OpenAPIDescription {
    /// A schema, reduced to the string `enum` values of its `anyOf` choices, and the default of the choice that has
    /// one.
    struct Schema: OpenAPIWordSchema {
        let choices: [Choice]

        private enum CodingKeys: String, CodingKey {
            case choices = "anyOf"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            choices = try container.decodeIfPresent([Choice].self, forKey: .choices) ?? []
        }

        /// The string values of every choice, in order, each once.
        var values: [String] {
            choices.flatMap(\.values).uniqued()
        }
    }

    /// One choice of a schema's `anyOf`: its string values and its default.
    struct Choice: Decodable {
        let values: [String]
        let defaultValue: String?

        private enum CodingKeys: String, CodingKey {
            case values = "enum"
            case defaultValue = "default"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            values = container.decodeStringValues(forKey: .values)
            defaultValue = try? container.decodeIfPresent(String.self, forKey: .defaultValue)
        }
    }

    /// The schemas that list model ids: Chat Completions' models, which the Responses API takes too, and the models
    /// only the Responses API takes.
    static let modelIDSchemaNames = ["ModelIdsShared", "ModelIdsResponses"]

    let components: OpenAPIComponents<Schema>

    /// The ids of the models the description lists for Chat Completions and the Responses API. OpenAI doesn't keep
    /// these lists whole, so they don't decide which models the catalog lists.
    func listedModelIDs() throws(MissingSchema) -> Set<String> {
        var ids: Set<String> = []
        for name in Self.modelIDSchemaNames {
            ids.formUnion(try words(ofSchema: name))
        }
        return ids
    }

    /// Every effort word, highest first, as the description lists them lowest first.
    func efforts() throws(MissingSchema) -> [String] {
        try words(ofSchema: Self.effortSchemaName).reversed()
    }

    /// The effort the description gives as the default for every model, or `nil` when it doesn't say. It isn't
    /// per model, so it may not be a model's own default.
    var defaultEffort: String? {
        components.schemas[Self.effortSchemaName]?.choices.lazy.compactMap(\.defaultValue).first
    }
}
