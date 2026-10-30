import Foundation
import LanguageModels

/// Reads what OpenRouter's API lists about a model, besides chat completions, and decodes it.
///
/// Each call is a `GET` to the base URL, or OpenRouter's own API, with the package's `User-Agent`, and with
/// `Authorization` only when the call has a key. It follows redirects only to the same host, so the key never reaches
/// another server. A failure throws what a chat request throws for the same response, a gateway failure is retried
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
    ///   - apiKey: The key to send, or `nil` to send none.
    ///   - type: The type of the answer's body.
    /// - Returns: The decoded body.
    /// - Throws: `OpenRouterError` with `invalidResponse` when the body doesn't decode, and otherwise what
    ///   ``OpenRouterFailure`` and a failed connection throw.
    func value<Value: Decodable & Sendable>(at path: String, apiKey: String?, as type: Value.Type) async throws -> Value {
        let request = try urlRequest(for: path, apiKey: apiKey)
        var log = CallLog(path: path)
        let key = request.url.map { InfoCache.Key(url: $0, apiKey: apiKey) }
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

    private func urlRequest(for path: String, apiKey: String?) throws -> URLRequest {
        guard let base = baseURL ?? API.defaultBaseURL else {
            throw OpenRouterError(message: "The base URL isn't valid.", code: .invalidRequest)
        }
        var request = URLRequest(url: base.appending(path: path))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(UserAgent.current, forHTTPHeaderField: "User-Agent")
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// The body of a successful response, after one retry of a gateway failure.
    private func data(for request: URLRequest, log: inout CallLog) async throws -> Data {
        var hasRetried = false
        while true {
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(for: request, delegate: SameHostRedirects())
            } catch let error as URLError {
                throw error.thrownError
            }
            let http = response as? HTTPURLResponse
            // A response that isn't HTTP has no status; 0 isn't a status OpenRouter sends.
            let status = http?.statusCode ?? 0
            log.received(status: status)
            if (200..<300).contains(status) { return data }
            if !hasRetried, API.gatewayStatuses.contains(status) {
                hasRetried = true
                log.retrying(after: retryDelay)
                try await Task.sleep(for: retryDelay)
                continue
            }
            let failure = OpenRouterFailure(
                status: status,
                body: try? API.decoder.decode(OpenRouterErrorResponse.Envelope.self, from: data.prefix(API.errorBodyLimit)).error,
                retryAfter: Duration(retryAfter: http?.value(forHTTPHeaderField: "Retry-After"))
                    ?? Duration(rateLimitReset: http?.value(forHTTPHeaderField: "X-RateLimit-Reset"))
            )
            throw failure.error(contextSize: nil)
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
