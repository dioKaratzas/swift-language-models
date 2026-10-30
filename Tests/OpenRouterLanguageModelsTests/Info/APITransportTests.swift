import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Info: transport")
struct APITransportTests {
    /// What a failed call surfaces as.
    enum Outcome: Sendable {
        case openRouterError(OpenRouterError.Code, status: Int?)
        case rateLimited
        case timeout
        case cancellation

        func matches(_ error: (any Error)?) -> Bool {
            switch (self, error) {
            case (.openRouterError(let code, let status), let error as OpenRouterError):
                return error.code == code && error.status == status
            case (.rateLimited, let error as LanguageModelError):
                if case .rateLimited = error { return true }
                return false
            case (.timeout, let error as LanguageModelError):
                if case .timeout = error { return true }
                return false
            case (.cancellation, let error):
                return error is CancellationError
            default:
                return false
            }
        }
    }

    @Test(arguments: [
        (
            401, #"{"error":{"message":"No cookie auth credentials found","code":401}}"#,
            Outcome.openRouterError(.authentication, status: 401)
        ),
        (404, #"{"error":{"message":"Not Found","code":404}}"#, .openRouterError(.notFound, status: 404)),
        (429, #"{"error":{"message":"Rate limit exceeded","code":429}}"#, .rateLimited),
        (500, "<html>Internal Server Error</html>", .openRouterError(.server, status: 500)),
        (524, #"{"error":{"message":"Timed out","code":524}}"#, .timeout),
    ])
    func `a failed response throws what a chat request throws for it`(status: Int, body: String, outcome: Outcome) async throws {
        let stub = HTTPStub(.json(body, status: status))

        let error = await #expect(throws: (any Error).self) { try await transport(stub).providers(of: "vendor/model", apiKey: nil) }

        #expect(outcome.matches(error), "Got \(String(describing: error))")
        #expect(stub.requests.count == 1)
    }

    @Test func `a rate limit carries its reset date from Retry-After`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"message":"Slow down","code":429}}"#, status: 429, headers: ["Retry-After": "30"]))

        let error = await #expect(throws: LanguageModelError.self) { try await transport(stub).providers(of: "vendor/model", apiKey: nil) }

        guard case .rateLimited(let context)? = error else {
            Issue.record("Expected a rate limit, got \(String(describing: error))")
            return
        }
        let wait = try #require(context.resetDate).timeIntervalSinceNow
        #expect((25...31).contains(wait))
    }

    @Test(arguments: [502, 503, 504, 529])
    func `a gateway failure is retried once`(status: Int) async throws {
        let stub = HTTPStub(.json("{}", status: status), try fixtureResponse("model-endpoints.json"))

        let providers = try await transport(stub).providers(of: "anthropic/claude-haiku-5.5", apiKey: nil)

        #expect(providers.count == 3)
        #expect(stub.requests.count == 2)
    }

    @Test func `a second gateway failure throws`() async throws {
        let stub = HTTPStub(.json("{}", status: 503), .json("{}", status: 503))

        let error = await #expect(throws: OpenRouterError.self) { try await transport(stub).providers(of: "vendor/model", apiKey: nil) }

        #expect(error?.code == .providerUnavailable)
        #expect(stub.requests.count == 2)
    }

    @Test(arguments: ["not json", #"{"data": {"endpoints": [{"tag": "vendor"}]}}"#, #"{"error": "no data"}"#])
    func `a body that doesn't decode throws an invalid response error`(body: String) async throws {
        let stub = HTTPStub(.json(body))

        let error = await #expect(throws: OpenRouterError.self) { try await transport(stub).providers(of: "vendor/model", apiKey: nil) }

        #expect(error?.code == .invalidResponse)
    }

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, Outcome.openRouterError(.connectionFailed, status: nil)),
        (.cannotFindHost, .openRouterError(.connectionFailed, status: nil)),
        (.timedOut, .timeout),
        (.cancelled, .cancellation),
    ])
    func `a connection that fails throws the matching error, without a retry`(code: URLError.Code, outcome: Outcome) async throws {
        let stub = HTTPStub(.failure(URLError(code)), try fixtureResponse("model-endpoints.json"))

        let error = await #expect(throws: (any Error).self) { try await transport(stub).providers(of: "vendor/model", apiKey: nil) }

        #expect(outcome.matches(error), "Got \(String(describing: error))")
        #expect(stub.requests.count == 1)
    }

    @Test func `an error that the language model's key closure throws passes through, before any request`() async throws {
        struct KeychainLocked: Error {}
        let stub = HTTPStub(try fixtureResponse("model-endpoints.json"))
        let languageModel = model(stub, efforts: [Efforts.Unsupported](), apiKey: { throw KeychainLocked() })

        await #expect(throws: KeychainLocked.self) { try await languageModel.providers() }
        #expect(stub.requests.isEmpty)
    }
}
