// snippet.profile
import FoundationModels
import OpenRouterLanguageModels

struct MealPlannerProfile: LanguageModelSession.DynamicProfile {
    let model: OpenRouterLanguageModel<Efforts.MaxXhighHighMediumLowOff>  // Claude Haiku 5.5's levels

    var body: some LanguageModelSession.DynamicProfile {
        LanguageModelSession.Profile { Instructions("Plan the week's meals.") }
            .model(model, effort: .xhigh)
    }
}

func planWeek() async throws -> String {
    let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, apiKey: { try await keyStore.openRouterKey() })
    let session = LanguageModelSession(profile: MealPlannerProfile(model: model))
    return try await session.respond(to: "Plan dinners for a busy week.").content
}
// snippet.end

// snippet.hide
func overrideLevel(session: LanguageModelSession) async throws {
    // snippet.show
    // snippet.request
    let response = try await session.respond(
        to: "Something quick for tonight.",
        contextOptions: ContextOptions(reasoningLevel: .low)
    )
    // snippet.end
    // snippet.hide
    _ = response
}

// snippet.show
// snippet.runtime
struct PickedModelProfile: LanguageModelSession.DynamicProfile {
    let model: OpenRouterLanguageModel<ContextOptions.ReasoningLevel>
    let effort: ContextOptions.ReasoningLevel

    var body: some LanguageModelSession.DynamicProfile {
        LanguageModelSession.Profile { Instructions("Plan the week's meals.") }
            .model(model, effort: effort)
    }
}

func session(forModelID id: OpenRouterModelID) -> LanguageModelSession? {
    guard let picked = OpenRouterModel(catalogID: id), let highest = picked.reasoningEfforts.first else { return nil }
    let model = OpenRouterLanguageModel(picked, apiKey: { try await keyStore.openRouterKey() })
    return LanguageModelSession(profile: PickedModelProfile(model: model, effort: highest))
}
// snippet.end

// snippet.hide
/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openRouterKey() async throws -> String { "" }
}

let keyStore = KeyStore()
