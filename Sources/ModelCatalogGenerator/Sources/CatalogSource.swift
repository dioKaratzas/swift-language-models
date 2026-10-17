import Foundation

/// A provider whose model list the generator reads.
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

    /// The fields of the raw model list whose words form a vocabulary, so new words get reported.
    var vocabularyFields: Set<String> {
        switch self {
        case .openrouter:
            [
                "data[].architecture.input_modalities[]",
                "data[].architecture.output_modalities[]",
                "data[].reasoning.supported_efforts[]",
                "data[].supported_parameters[]",
            ]
        }
    }

    /// The snapshot file, relative to the package root.
    var snapshotPath: String { "Catalogs/\(rawValue).json" }

    /// The schema file, relative to the package root.
    var schemaPath: String { "Catalogs/\(rawValue).schema.json" }

    /// Downloads the provider's raw model list.
    ///
    /// - Parameters:
    ///   - session: The session that sends the request.
    ///   - baseURL: Where the provider's API lives.
    /// - Returns: The response body.
    /// - Throws: ``GeneratorError/brokenSource(_:)`` for a network failure or an HTTP error.
    func modelList(using session: URLSession, baseURL: URL? = nil) async throws(GeneratorError) -> Data {
        guard let base = baseURL ?? URL(string: defaultBaseURL) else {
            throw .brokenSource("\(displayName) has an invalid base URL.")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: base.appending(path: "models"))
        } catch {
            throw .brokenSource("\(displayName) couldn't be reached: \(error.localizedDescription)")
        }
        let status = (response as? HTTPURLResponse)?.statusCode
        guard let status, (200..<300).contains(status) else {
            throw .brokenSource("\(displayName) returned HTTP \(status?.description ?? "without a status").")
        }
        return data
    }

    /// Decodes a raw model list into catalog models.
    ///
    /// - Parameter data: The response body.
    /// - Returns: The models, unsorted.
    /// - Throws: ``GeneratorError/brokenSource(_:)`` when the body doesn't decode.
    func catalogModels(from data: Data) throws(GeneratorError) -> [CatalogModel] {
        do {
            switch self {
            case .openrouter: return try OpenRouterModelsResponse.decoded(from: data).catalogModels
            }
        } catch {
            throw .brokenSource("\(displayName) returned a model list that doesn't decode: \(error)")
        }
    }

    /// The shape of a raw model list.
    ///
    /// - Parameter data: The response body.
    /// - Returns: The schema.
    /// - Throws: ``GeneratorError/brokenSource(_:)`` when the body isn't JSON.
    func schema(of data: Data) throws(GeneratorError) -> CatalogSchema {
        do {
            return try CatalogSchema(json: data, vocabularyFields: vocabularyFields)
        } catch {
            throw .brokenSource("\(displayName) returned a model list that isn't JSON: \(error)")
        }
    }
}
