import Foundation
import LanguageModels

/// Reads what OpenRouter's API lists about a model, besides chat completions, and decodes it.
///
/// Each call is a `GET` to the base URL, or OpenRouter's own API, with the package's `User-Agent` and the call's
/// authentication headers, if any. It follows redirects only to the same host, so the credentials never reach another
/// server. A failure throws what a chat request throws for the same response, a gateway failure is retried
/// once, and an answer from ``InfoCache`` that's still fresh is reused.
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
    func value<Value: Decodable & Sendable>(at path: String, headers: [String: String], as type: Value.Type) async throws -> Value {
        let request = try urlRequest(for: path, headers: headers)
        var log = CallLog(path: path, logger: .openRouter)
        let key = request.url.map { InfoCache.Key(url: $0, headers: headers) }
        if let key, let value = cache.value(for: key, as: Value.self) {
            log.answeredFromCache()
            return value
        }
        do {
            let value = try Self.decode(Value.self, from: try await data(for: request, log: &log))
            if let key { cache.store(value, for: key, lifetime: cacheLifetime) }
            log.finished()
            return value
        } catch {
            log.failed(error)
            throw error
        }
    }

    private func urlRequest(for path: String, headers: [String: String]) throws -> URLRequest {
        guard let base = baseURL ?? API.defaultBaseURL else {
            throw OpenRouterError(message: "The base URL isn't valid.", code: .invalidRequest)
        }
        return ProviderHTTP.request(url: base.appending(path: path), authHeaders: headers)
    }

    /// The body of a successful response, after one retry of a gateway failure.
    private func data(for request: URLRequest, log: inout CallLog) async throws -> Data {
        let http = ProviderHTTP(session: session, retryStatuses: API.gatewayStatuses, retryDelay: retryDelay)
        do {
            let (data, response) = try await http.data(request) { [log] in log.retrying(status: $0, after: retryDelay) }
            log.received(status: response?.statusCode ?? 0)
            return data
        } catch let failure as ProviderHTTP.Failure {
            throw OpenRouterFailure(failure).error(contextSize: nil)
        }
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try API.decoder.decode(Value.self, from: data)
        } catch {
            throw OpenRouterError(message: "OpenRouter sent a response that couldn't be read: \(error)", code: .invalidResponse)
        }
    }
}

/// The body of OpenRouter's answers, `{"data": …}`.
struct DataEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: Value
}
