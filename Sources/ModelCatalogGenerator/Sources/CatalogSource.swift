import Foundation

/// A provider whose models and vocabularies the generator reads.
enum CatalogSource: String, Codable, CaseIterable, Sendable {
    case openrouter

    /// The provider's name in messages and generated code.
    var displayName: String {
        switch self {
        case .openrouter: "OpenRouter"
        }
    }

    /// Where the provider's API lives.
    var defaultBaseURL: String {
        switch self {
        case .openrouter: "https://openrouter.ai/api/v1/"
        }
    }

    /// The availability attribute of a generated member whose model or word left the provider.
    var removedAttribute: String {
        "@available(*, unavailable, message: \(SwiftLiteral.string("Removed from \(displayName)")))"
    }

    /// The snapshot file, relative to the package root.
    var snapshotPath: String { "Catalogs/\(rawValue).json" }

    /// The schema file, relative to the package root.
    var schemaPath: String { "Catalogs/\(rawValue).schema.json" }

    /// The folder of the provider's generated sources, relative to the package root.
    var generatedDirectory: String {
        switch self {
        case .openrouter: "Sources/OpenRouterLanguageModels/Generated"
        }
    }

    /// The generated type that gives each word of a vocabulary a static member.
    func typeName(of vocabulary: CatalogVocabulary) -> String {
        switch (self, vocabulary) {
        case (.openrouter, .inputModalities): "OpenRouterInputModality"
        case (.openrouter, .outputModalities): "OpenRouterOutputModality"
        case (.openrouter, .parameters): "OpenRouterParameter"
        }
    }

    /// The fields of a document whose words form a vocabulary, so new words get reported.
    func vocabularyFields(in document: CatalogDocuments.Kind) -> Set<String> {
        switch (self, document) {
        case (.openrouter, .modelList):
            [
                "data[].architecture.input_modalities[]",
                "data[].architecture.output_modalities[]",
                "data[].reasoning.supported_efforts[]",
                "data[].supported_parameters[]",
            ]
        case (.openrouter, .apiDescription):
            Set(["InputModality", "OutputModality", "Parameter", "ReasoningEffort"].map { "components.schemas.\($0).enum[]" })
        }
    }

    /// Downloads the documents a fetch reads, one after the other.
    ///
    /// - Parameters:
    ///   - session: The session that sends the requests.
    ///   - baseURL: Where the provider's API lives.
    /// - Returns: The response bodies.
    /// - Throws: ``GeneratorError/brokenSource(_:)`` for a network failure or an HTTP error.
    func documents(using session: URLSession, baseURL: URL? = nil) async throws(GeneratorError) -> CatalogDocuments {
        guard let base = baseURL ?? URL(string: defaultBaseURL) else {
            throw .brokenSource("\(displayName) has an invalid base URL.")
        }
        return CatalogDocuments(
            modelList: try await download(.modelList, from: base, using: session),
            apiDescription: try await download(.apiDescription, from: base, using: session)
        )
    }

    /// The models and vocabularies the documents describe.
    ///
    /// - Parameter documents: The response bodies.
    /// - Returns: The models, unsorted, and the words of each vocabulary.
    /// - Throws: ``GeneratorError/brokenSource(_:)`` when a document doesn't decode.
    func catalog(from documents: CatalogDocuments) throws(GeneratorError) -> FetchedCatalog {
        switch self {
        case .openrouter:
            let (vocabularies, efforts) = try reading(.apiDescription, "doesn't decode") {
                let description = try OpenRouterAPIDescription.decoded(from: documents.apiDescription)
                return (try description.vocabularies(), try description.efforts())
            }
            let models = try reading(.modelList, "doesn't decode") {
                try OpenRouterModelsResponse.decoded(from: documents.modelList).catalogModels(everyEffort: efforts)
            }
            return FetchedCatalog(models: models, vocabularies: vocabularies)
        }
    }

    /// The shape of the documents: the model list's fields, and the vocabulary words of both.
    ///
    /// - Parameter documents: The response bodies.
    /// - Returns: The schema.
    /// - Throws: ``GeneratorError/brokenSource(_:)`` when a document isn't JSON.
    func schema(of documents: CatalogDocuments) throws(GeneratorError) -> CatalogSchema {
        let modelList = try reading(.modelList, "isn't JSON") {
            try CatalogSchema(json: documents.modelList, vocabularyFields: vocabularyFields(in: .modelList))
        }
        let apiDescription = try reading(.apiDescription, "isn't JSON") {
            try CatalogSchema(json: documents.apiDescription, vocabularyFields: vocabularyFields(in: .apiDescription))
        }
        return CatalogSchema(fields: modelList.fields, values: modelList.values.merging(apiDescription.values) { $1 })
    }

    /// Where a document lives, given the base URL of the provider's API.
    private func url(of document: CatalogDocuments.Kind, base: URL) -> URL? {
        switch (self, document) {
        case (.openrouter, .modelList):
            // OpenRouter lists only models that generate text unless asked otherwise; asking keeps that if the
            // default changes.
            base.appending(path: "models").appending(queryItems: [URLQueryItem(name: "output_modalities", value: "text")])
        case (.openrouter, .apiDescription):
            URL(string: "/openapi.json", relativeTo: base)?.absoluteURL
        }
    }

    private func download(
        _ document: CatalogDocuments.Kind,
        from base: URL,
        using session: URLSession
    ) async throws(GeneratorError) -> Data {
        guard let url = url(of: document, base: base) else {
            throw .brokenSource("\(displayName) has no address for \(document).")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw .brokenSource("\(displayName) couldn't be reached: \(error.localizedDescription)")
        }
        let status = (response as? HTTPURLResponse)?.statusCode
        guard let status, (200..<300).contains(status) else {
            throw .brokenSource("\(displayName) returned HTTP \(status?.description ?? "without a status") instead of \(document).")
        }
        return data
    }

    /// Runs a step that reads a document, turning its error into ``GeneratorError/brokenSource(_:)``.
    private func reading<Value>(
        _ document: CatalogDocuments.Kind,
        _ problem: String,
        _ step: () throws -> Value
    ) throws(GeneratorError) -> Value {
        do {
            return try step()
        } catch {
            throw .brokenSource("\(displayName) returned \(document) that \(problem): \(error)")
        }
    }
}
