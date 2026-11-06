import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenAILanguageModels
import Testing

@diagnose(DeprecatedDeclaration, as: warning)
extension LiveTests {
    @Suite("Guided generation")
    struct GuidedGeneration {
        @Test(arguments: [LiveModel.nano, .luna, .mini])
        func `a schema with nested types, an enum, a count and ranges decodes`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: try model.languageModel())

            let trip = try await session.respond(
                to: "Plan a short trip to Lisbon.", generating: Trip.self, contextOptions: model.quickContext
            ).content

            #expect(trip.activities.count == 3)
            #expect((1...14).contains(trip.days))
            #expect(trip.activities.allSatisfy { (1...12).contains($0.hours) })
        }

        @Test func `a guided answer cut off at its token limit throws instead of decoding`() async throws {
            let session = LanguageModelSession(model: try LiveModel.luna.languageModel())

            await #expect(throws: GeneratedContent.ParsingError.self) {
                _ = try await session.respond(
                    to: "Plan a short trip to Lisbon.", generating: Trip.self, options: GenerationOptions(maximumResponseTokens: 16),
                    contextOptions: LiveModel.luna.quickContext)
            }
        }
    }
}
