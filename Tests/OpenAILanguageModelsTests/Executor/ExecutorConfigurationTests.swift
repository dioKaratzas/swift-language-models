import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenAILanguageModels

/// An OpenAI model's configuration reaches its requests, and the initializer it replaced still works.
@Suite("Executor: configuration")
struct ExecutorConfigurationTests {
    private let plain: OpenAIModel<Efforts.Unsupported> = details(id: "gpt-plain", parameters: plainParameters, reasoning: .unsupported)

    @Test func `the idle timeout becomes the request's timeout`() async throws {
        let stub = HTTPStub(answer())
        let model = OpenAILanguageModel(
            plain, session: stub.session, configuration: OpenAIConfiguration(idleTimeout: .seconds(42)),
            auth: .apiKey(baseURL: stub.baseURL) { "sk-test" })

        _ = try await LanguageModelSession(model: model).respond(to: "Hi")

        #expect(try #require(stub.requests.first).request.timeoutInterval == 42)
    }

    @Test func `a change to the configuration applies to the next request`() async throws {
        let stub = HTTPStub(answer(), answer())
        var model = OpenAILanguageModel(plain, session: stub.session, auth: .apiKey(baseURL: stub.baseURL) { "sk-test" })

        _ = try await LanguageModelSession(model: model).respond(to: "Hi")
        model.configuration.idleTimeout = .seconds(7)
        _ = try await LanguageModelSession(model: model).respond(to: "Hi")

        #expect(model.idleTimeout == .seconds(7))
        #expect(model.executorConfiguration.settings.idleTimeout == .seconds(7))
        #expect(stub.requests.map(\.request.timeoutInterval) == [600, 7])
    }

    @Test func `the open form keeps the configuration`() {
        let configuration = OpenAIConfiguration(idleTimeout: .seconds(90), retries: .disabled, images: ImageEncoding(maximumSide: 512))
        let model = OpenAILanguageModel(plain, configuration: configuration, auth: .apiKey { "sk-test" })

        #expect(OpenAILanguageModel(model).configuration == configuration)
    }

    /// Code written before ``OpenAIConfiguration`` still builds, with a deprecation warning, and still sets the idle
    /// timeout.
    @available(*, deprecated)
    @Test func `the initializer with an idle timeout still sets it`() {
        let model = OpenAILanguageModel(plain, idleTimeout: .seconds(30), auth: .apiKey { "sk-test" })

        #expect(model.idleTimeout == .seconds(30))
        #expect(model.configuration.retries == .standard)
        #expect(model.configuration.images == .standard)
    }

    private func answer() -> StubResponse {
        responseStream([created()], [textDelta("Hi."), completed()])
    }
}
