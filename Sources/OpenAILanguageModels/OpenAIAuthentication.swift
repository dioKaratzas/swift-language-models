public import Foundation
import LanguageModels

/// How a model's requests authenticate, and where they go: to OpenAI with an API key, with a key to another server that
/// speaks OpenAI's API, or to a server of your own that adds the key and forwards them.
///
/// ```swift
/// // An API key, for development, or a key the person brings, kept in the Keychain:
/// OpenAILanguageModel(.gpt6Luna, auth: .apiKey { try await keyStore.openAIKey() })
///
/// // Your own server, which adds the key and forwards each request to OpenAI, so the app ships no key:
/// OpenAILanguageModel(
///     .gpt6Luna,
///     auth: .proxied(baseURL: proxyURL, headers: { ["X-App-Token": try await account.appToken()] })
/// )
/// ```
///
/// A key inside an app can be extracted from it, so an app that ships uses ``proxied(baseURL:headers:)``, or a key each
/// person brings.
public struct OpenAIAuthentication: Sendable {
    /// The server that stands in for OpenAI's API, from ``apiKey(baseURL:organization:project:_:)`` or
    /// ``proxied(baseURL:headers:)``, or `nil` for OpenAI's API itself.
    public var baseURL: URL? { requestAuthentication.baseURL }

    /// The headers that authenticate a request, read for every request, and where it goes, as a request's connection
    /// holds them.
    let requestAuthentication: RequestAuthentication

    private init(_ requestAuthentication: RequestAuthentication) {
        self.requestAuthentication = requestAuthentication
    }

    /// Authentication with these headers, sent to a base URL, such as a test server's.
    init(baseURL: URL?, headers: @escaping @Sendable () async throws -> [String: String]) {
        self.init(RequestAuthentication(baseURL: baseURL, headers: headers))
    }

    /// Reads the headers, and throws a `URLError` that reading them throws the way a failed connection's is thrown.
    func requestHeaders() async throws -> [HTTPHeaderName: String] {
        try await requestAuthentication.requestHeaders()
    }

    /// An OpenAI API key, sent to OpenAI as a bearer token.
    ///
    /// - Parameters:
    ///   - organization: The organization the requests count toward, sent as `OpenAI-Organization`, or `nil` for the
    ///     key's default.
    ///   - project: The project the requests count toward, sent as `OpenAI-Project`, or `nil` for the key's default.
    ///   - key: Returns the key. It's called for every request and never stored. An empty key sends no
    ///     `Authorization` header.
    /// - Returns: The authentication.
    public static func apiKey(
        organization: String? = nil,
        project: String? = nil,
        _ key: @escaping @Sendable () async throws -> String
    ) -> Self {
        Self(apiKey: key, baseURL: nil, organization: organization, project: project)
    }

    /// An OpenAI API key, sent as a bearer token to another server that speaks OpenAI's API, such as a gateway of your
    /// company's or a test server.
    ///
    /// Requests go to the same paths under `baseURL` as under OpenAI's API, such as `responses`, and follow redirects
    /// only to the same host. To keep the key out of the app, use ``proxied(baseURL:headers:)`` instead.
    ///
    /// - Parameters:
    ///   - baseURL: The server's URL, which stands in for `https://api.openai.com/v1/`.
    ///   - organization: The organization the requests count toward, sent as `OpenAI-Organization`, or `nil` for the
    ///     key's default.
    ///   - project: The project the requests count toward, sent as `OpenAI-Project`, or `nil` for the key's default.
    ///   - key: Returns the key. It's called for every request and never stored. An empty key sends no
    ///     `Authorization` header.
    /// - Returns: The authentication.
    public static func apiKey(
        baseURL: URL,
        organization: String? = nil,
        project: String? = nil,
        _ key: @escaping @Sendable () async throws -> String
    ) -> Self {
        Self(apiKey: key, baseURL: baseURL, organization: organization, project: project)
    }

    /// A server of your own that stands in for OpenAI's API: it adds the API key and forwards each request, so the app
    /// ships no key.
    ///
    /// Requests go to the same paths under `baseURL` as under OpenAI's API, such as `responses`, and follow redirects
    /// only to the same host.
    ///
    /// - Parameters:
    ///   - baseURL: The server's URL, which stands in for `https://api.openai.com/v1/`.
    ///   - headers: Returns the headers that let the server authorize the caller, such as a token of your app's own.
    ///     It's called for every request, so a token can refresh. Return `[:]` when the server needs none.
    /// - Returns: The authentication.
    public static func proxied(
        baseURL: URL,
        headers: @escaping @Sendable () async throws -> [String: String] = { [:] }
    ) -> Self {
        Self(baseURL: baseURL, headers: headers)
    }

    /// An API key sent as a bearer token to OpenAI's API, or to the base URL that stands in for it, with the
    /// organization and project when set.
    private init(apiKey key: @escaping @Sendable () async throws -> String, baseURL: URL?, organization: String?, project: String?) {
        self.init(
            .apiKey(key, baseURL: baseURL) { key in
                var headers: [HTTPHeaderName: String] = [.authorization: "Bearer \(key)"]
                headers[API.Header.organization] = organization
                headers[API.Header.project] = project
                return headers
            })
    }
}
