import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: app attribution")
struct ExecutorAttributionTests {
    @Test func `the app's name, website, first two categories and visibility go in OpenRouter's headers`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let details = OpenRouterModel<Efforts.Unsupported>(
            id: "vendor/model", displayName: "Vendor: Model", releaseDate: .distantPast, supportedParameters: chatParameters)
        let app = OpenRouterApp(
            name: "Coach", url: URL(string: "https://coach.example"), categories: [.personalAgent, .generalChat, .writingAssistant],
            isHidden: true)
        let model = OpenRouterLanguageModel(details, app: app, baseURL: stub.baseURL, session: stub.session) { "sk-or-test" }

        _ = try await LanguageModelSession(model: model).respond(to: "Hi")

        let request = try #require(stub.requests.first).request
        #expect(request.value(forHTTPHeaderField: "HTTP-Referer") == "https://coach.example")
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Title") == "Coach")
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Categories") == "personal-agent,general-chat")
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-App-Visibility") == "hidden")
    }

    @Test func `every request names the package in its User-Agent, a retried one too`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":503,"message":"Unavailable"}}"#, status: 503), events(text("Hi"), done()))

        try await respond(stub)

        let userAgents = stub.requests.map { $0.request.value(forHTTPHeaderField: "User-Agent") }
        #expect(userAgents == [UserAgent.current, UserAgent.current])
        #expect(UserAgent.current.hasPrefix("swift-language-models/"))
    }

    @Test func `an app without categories that isn't hidden sends neither header`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))

        try await respond(stub)

        let request = try #require(stub.requests.first).request
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Categories") == nil)
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-App-Visibility") == nil)
    }

    @Test func `the model reads back its app, base URL and idle timeout, and so does the open form`() throws {
        let app = OpenRouterApp(name: "Coach", url: URL(string: "https://coach.example"), categories: [.personalAgent])
        let baseURL = try #require(URL(string: "https://proxy.example/openrouter/"))
        let model = OpenRouterLanguageModel(.openaiGpt5Mini, app: app, baseURL: baseURL, idleTimeout: .seconds(90)) { "sk-or-test" }

        #expect(model.app == app)
        #expect(model.baseURL == baseURL)
        #expect(model.idleTimeout == .seconds(90))
        let open = OpenRouterLanguageModel(model)
        #expect(open.app == app)
        #expect(open.baseURL == baseURL)
        #expect(open.idleTimeout == .seconds(90))
    }

    @Test func `a model without settings names no app and keeps OpenRouter's address and the session's timeout`() {
        let model = OpenRouterLanguageModel(.openaiGpt5Mini) { "sk-or-test" }

        #expect(model.app == OpenRouterApp())
        #expect(model.baseURL == nil)
        #expect(model.idleTimeout == nil)
    }

    @Test func `the idle timeout becomes the request's timeout`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let details = OpenRouterModel<Efforts.Unsupported>(
            id: "vendor/model", displayName: "Vendor: Model", releaseDate: .distantPast, supportedParameters: chatParameters)
        let model = OpenRouterLanguageModel(details, baseURL: stub.baseURL, session: stub.session, idleTimeout: .seconds(42)) {
            "sk-or-test"
        }

        _ = try await LanguageModelSession(model: model).respond(to: "Hi")

        #expect(try #require(stub.requests.first).request.timeoutInterval == 42)
    }
}
