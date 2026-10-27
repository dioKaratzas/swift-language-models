import Foundation

/// OpenRouter's OpenAPI description, reduced to the schemas the catalog reads.
struct OpenRouterAPIDescription: Decodable {
    struct Components: Decodable {
        let schemas: [String: Schema]
    }

    /// A schema, reduced to its description, its string values and its properties.
    struct Schema: Decodable {
        let description: String?
        /// The schema's string `enum` values, in order, each once.
        let values: [String]
        let properties: [String: Property]

        private enum CodingKeys: String, CodingKey {
            case description
            case values = "enum"
            case properties
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            description = try container.decodeIfPresent(String.self, forKey: .description)
            // Some schemas list numbers, which no vocabulary uses.
            values = (try? container.decodeIfPresent([String?].self, forKey: .values))?.compactMap(\.self).uniqued() ?? []
            properties = try container.decodeIfPresent([String: Property].self, forKey: .properties) ?? [:]
        }
    }

    /// A property of a schema: its own description, or a reference to the schema that describes it.
    struct Property: Decodable {
        let description: String?
        let reference: String?

        private enum CodingKeys: String, CodingKey {
            case description
            case reference = "$ref"
        }
    }

    /// A schema the catalog needs is missing, or lists no words.
    struct MissingSchema: Error, CustomStringConvertible {
        let name: String

        var description: String { "it has no words for the \(name) schema" }
    }

    /// The schema that lists every effort word, highest first.
    static let effortSchemaName = "ReasoningEffort"

    /// Every schema whose words the catalog reads.
    static var wordSchemaNames: [String] {
        CatalogSource.openrouter.vocabularies.map(schemaName(of:)) + [effortSchemaName]
    }

    let components: Components

    /// The schema that lists a vocabulary's words.
    static func schemaName(of vocabulary: CatalogVocabulary) -> String {
        switch vocabulary {
        case .inputModalities: "InputModality"
        case .outputModalities: "OutputModality"
        case .parameters: "Parameter"
        case .searchContextSizes: "SearchQualityLevel"
        case .webFetchEngines: "WebFetchEngineEnum"
        case .webSearchEngines: "WebSearchEngineEnum"
        case .webSearchModes: "WebSearchMode"
        }
    }

    static func decoded(from data: Data) throws -> OpenRouterAPIDescription {
        try JSONDecoder().decode(OpenRouterAPIDescription.self, from: data)
    }

    /// Every effort word, highest first.
    func efforts() throws(MissingSchema) -> [String] {
        try words(ofSchema: Self.effortSchemaName)
    }

    /// The words of each vocabulary. A parameter's summary is the description of its chat request field.
    func vocabularies() throws(MissingSchema) -> [CatalogVocabulary: [CatalogWord]] {
        let requestFields = components.schemas["ChatRequest"]?.properties ?? [:]
        var vocabularies: [CatalogVocabulary: [CatalogWord]] = [:]
        for vocabulary in CatalogSource.openrouter.vocabularies {
            vocabularies[vocabulary] = try words(of: vocabulary).map { word in
                CatalogWord(word, summary: vocabulary == .parameters ? requestFields[word].flatMap(summary) : nil)
            }
        }
        return vocabularies
    }

    private func words(of vocabulary: CatalogVocabulary) throws(MissingSchema) -> [String] {
        try words(ofSchema: Self.schemaName(of: vocabulary))
    }

    private func words(ofSchema schema: String) throws(MissingSchema) -> [String] {
        guard let words = components.schemas[schema]?.values, !words.isEmpty else { throw MissingSchema(name: schema) }
        return words
    }

    /// A property's description, or that of the schema it refers to, on one line and ending in a period.
    private func summary(of property: Property) -> String? {
        let referenced = property.reference?.split(separator: "/").last.flatMap { components.schemas[String($0)]?.description }
        guard let text = property.description ?? referenced else { return nil }
        let line = SourceText.docText(text)
        guard let last = line.last else { return nil }
        return ".!?".contains(last) ? line : line + "."
    }
}
