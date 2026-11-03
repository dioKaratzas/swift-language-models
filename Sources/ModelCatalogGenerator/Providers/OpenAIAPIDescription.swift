import Foundation

/// OpenAI's OpenAPI description, reduced to what the catalog reads: the ids of the models that take the Responses API,
/// and the effort words.
struct OpenAIAPIDescription: Decodable {
    struct Components: Decodable {
        let schemas: [String: Schema]
    }

    /// A schema, reduced to the string `enum` values of its `anyOf` choices, and the default of the choice that has one.
    struct Schema: Decodable {
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
            values = (try? container.decodeIfPresent([String?].self, forKey: .values))?.compactMap(\.self) ?? []
            defaultValue = try? container.decodeIfPresent(String.self, forKey: .defaultValue)
        }
    }

    /// A schema the catalog needs is missing, or lists no words.
    struct MissingSchema: Error, CustomStringConvertible {
        let name: String

        var description: String { "it has no words for the \(name) schema" }
    }

    /// The schemas that list the ids of the models that take the Responses API: the ones every API takes, and the
    /// ones only the Responses API takes.
    static let responsesModelSchemaNames = ["ModelIdsShared", "ModelIdsResponses"]

    /// The schema that lists every effort word, lowest first, with the default.
    static let effortSchemaName = "ReasoningEffort"

    let components: Components

    static func decoded(from data: Data) throws -> OpenAIAPIDescription {
        try JSONDecoder().decode(OpenAIAPIDescription.self, from: data)
    }

    /// The ids of the models that take the Responses API.
    func responsesModelIDs() throws(MissingSchema) -> Set<String> {
        var ids: Set<String> = []
        for name in Self.responsesModelSchemaNames {
            ids.formUnion(try words(ofSchema: name))
        }
        return ids
    }

    /// Every effort word, highest first.
    func efforts() throws(MissingSchema) -> [String] {
        try words(ofSchema: Self.effortSchemaName).reversed()
    }

    /// The effort a model uses when a request doesn't set one, or `nil` when the description doesn't say.
    var defaultEffort: String? {
        components.schemas[Self.effortSchemaName]?.choices.lazy.compactMap(\.defaultValue).first
    }

    private func words(ofSchema schema: String) throws(MissingSchema) -> [String] {
        guard let words = components.schemas[schema]?.values, !words.isEmpty else { throw MissingSchema(name: schema) }
        return words
    }
}
