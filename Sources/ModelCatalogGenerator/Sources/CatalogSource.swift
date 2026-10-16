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

    /// The snapshot file, relative to the package root.
    var snapshotPath: String { "Catalogs/\(rawValue).json" }

    /// Downloads the provider's current models.
    ///
    /// - Parameters:
    ///   - session: The session that sends the request.
    ///   - baseURL: Where the provider's API lives.
    /// - Returns: The models, unsorted.
    /// - Throws: ``GeneratorError/brokenSource(_:)`` for a network failure, an HTTP error, or a body that doesn't
    ///   decode.
    func fetch(using session: URLSession, baseURL: URL? = nil) async throws(GeneratorError) -> [CatalogModel] {
        guard let base = baseURL ?? URL(string: defaultBaseURL) else {
            throw .brokenSource("\(displayName) has an invalid base URL.")
        }
        let url = base.appending(path: "models")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw .brokenSource("\(displayName) couldn't be reached: \(error.localizedDescription)")
        }
        let status = (response as? HTTPURLResponse)?.statusCode
        guard let status, (200..<300).contains(status) else {
            throw .brokenSource("\(displayName) returned HTTP \(status?.description ?? "without a status").")
        }
        do {
            switch self {
            case .openrouter: return try OpenRouterModelsResponse.decoded(from: data).catalogModels
            }
        } catch {
            throw .brokenSource("\(displayName) returned a model list that doesn't decode: \(error)")
        }
    }
}
