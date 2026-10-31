import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Synchronization
import Testing

@testable import OpenRouterLanguageModels

@Suite("Authentication")
struct AuthenticationTests {
    @Test func `an API key goes to OpenRouter as a bearer token`() async throws {
        let auth = OpenRouterAuthentication.apiKey { "sk-or-key" }

        #expect(auth.baseURL == nil)
        #expect(try await auth.headers() == ["Authorization": "Bearer sk-or-key"])
    }

    @Test func `an empty API key sends no headers`() async throws {
        #expect(try await OpenRouterAuthentication.apiKey { "" }.headers().isEmpty)
    }

    @Test func `a proxied model sends its headers, and no Authorization of its own, to its base URL`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let model = OpenRouterLanguageModel(
            .openaiGpt4_1Nano,
            session: stub.session,
            auth: .proxied(baseURL: stub.baseURL.appending(path: "openrouter"), headers: { ["X-App-Token": "app-token"] })
        )

        _ = try await LanguageModelSession(model: model).respond(to: "Hi")

        let request = try #require(stub.requests.first?.request)
        #expect(request.url?.path() == "/openrouter/chat/completions")
        #expect(request.value(forHTTPHeaderField: "X-App-Token") == "app-token")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func `a proxy without headers sends only the package's own`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let model = OpenRouterLanguageModel(.openaiGpt4_1Nano, session: stub.session, auth: .proxied(baseURL: stub.baseURL))

        _ = try await LanguageModelSession(model: model).respond(to: "Hi")

        let request = try #require(stub.requests.first?.request)
        let names = Set(request.allHTTPHeaderFields?.keys.map { $0.lowercased() } ?? [])
        #expect(names == ["accept", "content-length", "content-type", "user-agent"])
    }

    @Test func `the headers are read again for every request, so a token can refresh`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()), events(text("Again"), done()))
        let reads = Mutex(0)
        let model = OpenRouterLanguageModel(
            .openaiGpt4_1Nano,
            session: stub.session,
            auth: .proxied(baseURL: stub.baseURL) {
                let read = reads.withLock { reads in
                    reads += 1
                    return reads
                }
                return ["X-App-Token": "token-\(read)"]
            }
        )
        let session = LanguageModelSession(model: model)

        _ = try await session.respond(to: "Hi")
        _ = try await session.respond(to: "Again")

        #expect(stub.requests.map { $0.request.value(forHTTPHeaderField: "X-App-Token") } == ["token-1", "token-2"])
    }

    @Test func `the package's own headers take precedence over the authentication's`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let model = OpenRouterLanguageModel(
            .openaiGpt4_1Nano,
            session: stub.session,
            auth: .proxied(baseURL: stub.baseURL, headers: { ["Content-Type": "text/plain"] })
        )

        _ = try await LanguageModelSession(model: model).respond(to: "Hi")

        #expect(stub.requests.first?.request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func `a proxied model's info calls go to its base URL with its headers`() async throws {
        let stub = HTTPStub(try fixtureResponse("model-endpoints.json"))
        let model = OpenRouterLanguageModel(
            .anthropicClaudeHaiku5_5,
            session: stub.session,
            auth: .proxied(baseURL: stub.baseURL.appending(path: "openrouter"), headers: { ["X-App-Token": "app-token"] })
        )

        _ = try await model.providers()

        let request = try #require(stub.requests.first?.request)
        #expect(request.url?.path() == "/openrouter/models/anthropic/claude-haiku-5.5/endpoints")
        #expect(request.value(forHTTPHeaderField: "X-App-Token") == "app-token")
    }

    @Test func `a URLError that the headers throw maps as a failed connection's does, on an info call too`() async throws {
        let stub = HTTPStub(try fixtureResponse("model-endpoints.json"))
        let model = OpenRouterLanguageModel(
            .anthropicClaudeHaiku5_5,
            session: stub.session,
            auth: .proxied(baseURL: stub.baseURL) { throw URLError(.notConnectedToInternet) }
        )

        let error = await #expect(throws: OpenRouterError.self) { try await model.providers() }

        #expect(error?.code == .connectionFailed)
        #expect(stub.requests.isEmpty)
    }

    @Test func `an error the headers throw fails the request before anything is sent`() async throws {
        struct TokenExpired: Error {}
        let stub = HTTPStub(events(text("Hi"), done()))
        let model = OpenRouterLanguageModel(
            .openaiGpt4_1Nano,
            session: stub.session,
            auth: .proxied(baseURL: stub.baseURL) { throw TokenExpired() }
        )

        await #expect(throws: TokenExpired.self) { try await LanguageModelSession(model: model).respond(to: "Hi") }
        #expect(stub.requests.isEmpty)
    }
}
