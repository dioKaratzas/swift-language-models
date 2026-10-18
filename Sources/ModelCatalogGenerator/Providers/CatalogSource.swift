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

    /// The snapshot file, relative to the package root.
    var snapshotPath: String { "Catalogs/\(rawValue).json" }

    /// The schema file, relative to the package root.
    var schemaPath: String { "Catalogs/\(rawValue).schema.json" }

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
            Set(OpenRouterAPIDescription.wordSchemaNames.map { "components.schemas.\($0).enum[]" })
        }
    }

    /// Downloads the documents a fetch reads, one after the other.
    ///
    /// A request that fails without a response, as a network failure does, is sent once more after a pause.
    ///
    /// - Parameters:
    ///   - session: The session that sends the requests.
    ///   - baseURL: Where the provider's API lives.
    ///   - retryDelay: The pause before a failed request is sent again.
    /// - Returns: The response bodies.
    /// - Throws: ``GeneratorError/brokenSource(_:)`` for a network failure or an HTTP error.
    func documents(
        using session: URLSession,
        baseURL: URL? = nil,
        retryDelay: Duration = .seconds(2)
    ) async throws(GeneratorError) -> CatalogDocuments {
        guard let base = baseURL ?? URL(string: defaultBaseURL) else {
            throw .brokenSource("\(displayName) has an invalid base URL.")
        }
        return CatalogDocuments(
            modelList: try await download(.modelList, from: base, using: session, retryDelay: retryDelay),
            apiDescription: try await download(.apiDescription, from: base, using: session, retryDelay: retryDelay)
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
            return FetchedCatalog(models: models, vocabularies: vocabularies, efforts: efforts)
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
        using session: URLSession,
        retryDelay: Duration
    ) async throws(GeneratorError) -> Data {
        guard let url = url(of: document, base: base) else {
            throw .brokenSource("\(displayName) has no address for \(document).")
        }
        let data: Data
        let response: URLResponse
        do {
            do {
                (data, response) = try await session.data(from: url)
            } catch {
                try await Task.sleep(for: retryDelay)
                (data, response) = try await session.data(from: url)
            }
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
