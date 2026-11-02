import Foundation
import LanguageModels

/// Reads what OpenRouter's API lists about a model, besides chat completions, and decodes it, through the core's
/// ``InfoTransport``: to the base URL, or OpenRouter's own API, with a failure thrown as a chat request's would be.
struct APITransport: Sendable {
    let session: URLSession
    let baseURL: URL?

    /// How long an answer stays fresh in the cache.
    var cacheLifetime: Duration = .seconds(60)

    /// The wait before the one retry of a gateway failure.
    var retryDelay: Duration = .seconds(1)

    var cache = InfoCache.shared

    /// Reads a path and decodes the answer's body, or reuses a fresh answer from the cache.
    ///
    /// - Parameters:
    ///   - path: The path under the base URL, such as `models/anthropic/claude-haiku-5.5/endpoints`.
    ///   - headers: The headers that authenticate the call, or none.
    ///   - type: The type of the answer's body.
    /// - Returns: The decoded body.
    /// - Throws: `OpenRouterError` with `invalidResponse` when the body doesn't decode, and otherwise what
    ///   ``OpenRouterFailure`` and a failed connection throw.
    func value<Value: Decodable & Sendable>(at path: String, headers: [HTTPHeaderName: String], as type: Value.Type) async throws -> Value {
        let base = try API.baseURL(baseURL)
        let http = ProviderHTTP(session: session, retryStatuses: ProviderHTTP.gatewayStatuses, retryDelay: retryDelay)
        let transport = InfoTransport(http: http, logger: .openRouter, cacheLifetime: cacheLifetime, cache: cache)
        return try await transport.value(
            at: base.appending(path: path), path: path, headers: headers, decode: Self.decode,
            failure: { (rejection: HTTPRejection<OpenRouterErrorResponse>) in OpenRouterFailure(rejection).error(contextSize: nil) })
    }

    private static func decode<Value: Decodable>(_ data: Data) throws -> Value {
        do {
            return try ProviderHTTP.decoder.decode(Value.self, from: data)
        } catch {
            throw OpenRouterError(message: "OpenRouter sent a response that couldn't be read: \(error)", code: .invalidResponse)
        }
    }
}

extension APITransport {
    /// The body of OpenRouter's answers, `{"data": …}`.
    struct DataEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
        let data: Value
    }
}
