import FoundationModels
import LanguageModels
import Testing

@Suite("Profile effort")
struct DynamicProfileEffortTests {
    @Test(arguments: [HighLowEffort.high, .low])
    func `a profile sends its typed effort to the model`(effort: HighLowEffort) async throws {
        let session = LanguageModelSession(profile: EchoProfile(effort: effort))

        let response = try await session.respond(to: "Which level?")

        #expect(response.content == effort.rawValue)
    }

    @Test func `a runtime level reaches the model unchanged`() async throws {
        let model = EchoModel<ContextOptions.ReasoningLevel>(efforts: [])
        let profile = LanguageModelSession.Profile { Instructions("Echo the reasoning level.") }
            .model(model, effort: .custom("none"))
        let session = LanguageModelSession(profile: profile)

        let response = try await session.respond(to: "Which level?")

        #expect(response.content == "none")
    }

    @Test func `a model without an effort sends no reasoning level`() async throws {
        let profile = LanguageModelSession.Profile { Instructions("Echo the reasoning level.") }
            .model(EchoModel<HighLowEffort>(efforts: [.high]))
        let session = LanguageModelSession(profile: profile)

        let response = try await session.respond(to: "Which level?")

        #expect(response.content == "default")
    }

    @Test func `an outer reasoning level doesn't replace the typed effort`() async throws {
        let session = LanguageModelSession(profile: EchoProfile(effort: .low).reasoningLevel(.deep))

        let response = try await session.respond(to: "Which level?")

        #expect(response.content == "low")
    }

    @Test func `a request's context options replace the typed effort`() async throws {
        let session = LanguageModelSession(profile: EchoProfile(effort: .low))

        let response = try await session.respond(to: "Which level?", contextOptions: ContextOptions(reasoningLevel: .deep))

        #expect(response.content == "deep")
    }

    @Test func `a detailed model takes its capabilities from its details`() {
        let model = EchoModel<HighLowEffort>(efforts: [.high, .low])

        #expect(model.capabilities.contains(.toolCalling))
        #expect(model.capabilities.contains(.reasoning))
        #expect(!model.capabilities.contains(.vision))
    }
}

private struct EchoProfile: LanguageModelSession.DynamicProfile {
    let effort: HighLowEffort

    var body: some LanguageModelSession.DynamicProfile {
        LanguageModelSession.Profile { Instructions("Echo the reasoning level.") }
            .model(EchoModel(efforts: [HighLowEffort.high, .low]), effort: effort)
    }
}
