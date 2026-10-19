import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTesting
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: app attribution")
struct ExecutorAttributionTests {
    @Test func `the app's name, website, first two categories and visibility go in OpenRouter's headers`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let details = OpenRouterModel<Efforts.Unsupported>(
            id: "vendor/model", displayName: "Vendor: Model", releaseDate: .distantPast, supportedParameters: chatParameters)
        let model = OpenRouterLanguageModel(
            details,
            appName: "Coach",
            appURL: URL(string: "https://coach.example"),
            appCategories: [.personalAgent, .generalChat, .writingAssistant],
            hidesApp: true,
            baseURL: stub.baseURL,
            session: stub.session
        ) { "sk-or-test" }

        _ = try await LanguageModelSession(model: model).respond(to: "Hi")

        let request = try #require(stub.requests.first).request
        #expect(request.value(forHTTPHeaderField: "HTTP-Referer") == "https://coach.example")
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Title") == "Coach")
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Categories") == "personal-agent,general-chat")
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-App-Visibility") == "hidden")
    }

    @Test func `an app without categories that isn't hidden sends neither header`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))

        try await respond(stub)

        let request = try #require(stub.requests.first).request
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Categories") == nil)
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-App-Visibility") == nil)
    }
}
