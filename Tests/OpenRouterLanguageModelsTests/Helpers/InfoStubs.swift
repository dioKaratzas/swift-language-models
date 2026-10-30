import Foundation
import LanguageModelsTestSupport

@testable import OpenRouterLanguageModels

/// A JSON response whose body is a fixture saved from OpenRouter, or built from its API description.
func fixtureResponse(_ name: String, status: Int = 200) throws -> StubResponse {
    .json(String(decoding: try Bundle.module.fixture(name), as: UTF8.self), status: status)
}

/// A transport to a stub with a cache of its own, and no wait before a retry.
func transport(_ stub: HTTPStub, cacheLifetime: Duration = .seconds(60)) -> APITransport {
    APITransport(session: stub.session, baseURL: stub.baseURL, cacheLifetime: cacheLifetime, retryDelay: .zero, cache: InfoCache())
}

/// The value of a header of the request the stub received at an index.
func header(_ name: String, of stub: HTTPStub, at index: Int = 0) -> String? {
    stub.requests.indices.contains(index) ? stub.requests[index].request.value(forHTTPHeaderField: name) : nil
}
