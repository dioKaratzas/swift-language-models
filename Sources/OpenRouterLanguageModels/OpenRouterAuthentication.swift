public import Foundation

/// How a model's requests authenticate, and where they go: to OpenRouter with an API key, or to a server of your own
/// that adds the key and forwards them.
///
/// ```swift
/// // An API key, for development, or a key the person brings, kept in the Keychain:
/// OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, auth: .apiKey { try await keyStore.openRouterKey() })
///
/// // Your own server, which adds the key and forwards each request to OpenRouter, so the app ships no key:
/// OpenRouterLanguageModel(
///     .anthropicClaudeHaiku5_5,
///     auth: .proxied(baseURL: proxyURL, headers: { ["X-App-Token": try await account.appToken()] })
/// )
/// ```
///
/// A key inside an app can be extracted from it, so an app that ships uses ``proxied(baseURL:headers:)``, or a key
/// each person brings.
public struct OpenRouterAuthentication: Sendable {
    /// The server that stands in for OpenRouter's API, from ``proxied(baseURL:headers:)``, or `nil` for OpenRouter's
    /// API itself.
    public let baseURL: URL?

    /// The headers that authenticate a request, read for every request.
    let headers: @Sendable () async throws -> [String: String]

    init(baseURL: URL?, headers: @escaping @Sendable () async throws -> [String: String]) {
        self.baseURL = baseURL
        self.headers = headers
    }

    /// Reads the headers, and throws a `URLError` that reading them throws as a failed connection's error.
    func requestHeaders() async throws -> [String: String] {
        do {
            return try await headers()
        } catch let error as URLError {
            throw error.thrownError
        }
    }

    /// An OpenRouter API key, sent to OpenRouter as a bearer token.
    ///
    /// - Parameter key: Returns the key. It's called for every request and never stored. An empty key sends no
    ///   `Authorization` header.
    /// - Returns: The authentication.
    public static func apiKey(_ key: @escaping @Sendable () async throws -> String) -> Self {
        apiKey(key, baseURL: nil)
    }

    /// A server of your own that stands in for OpenRouter's API: it adds the API key and forwards each request, so the
    /// app ships no key.
    ///
    /// Requests go to the same paths under `baseURL` as under OpenRouter's API, such as `chat/completions`, and follow
    /// redirects only to the same host. Model info calls, such as `providers()`, go there too.
    ///
    /// - Parameters:
    ///   - baseURL: The server's URL, which stands in for `https://openrouter.ai/api/v1/`.
    ///   - headers: Returns the headers that let the server authorize the caller, such as a token of your app's own.
    ///     It's called for every request, so a token can refresh. Return `[:]` when the server needs none.
    /// - Returns: The authentication.
    public static func proxied(
        baseURL: URL,
        headers: @escaping @Sendable () async throws -> [String: String] = { [:] }
    ) -> Self {
        Self(baseURL: baseURL, headers: headers)
    }

    /// An API key sent as a bearer token to OpenRouter, or to another base URL, such as a test server's.
    static func apiKey(_ key: @escaping @Sendable () async throws -> String, baseURL: URL?) -> Self {
        Self(baseURL: baseURL) {
            let key = try await key()
            return key.isEmpty ? [:] : ["Authorization": "Bearer \(key)"]
        }
    }
}
