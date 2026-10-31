// snippet.profile
import FoundationModels
import OpenRouterLanguageModels

struct MealPlannerProfile<Model: DetailedLanguageModel>: LanguageModelSession.DynamicProfile {
    let model: Model
    let effort: Model.Details.Effort

    var body: some LanguageModelSession.DynamicProfile {
        LanguageModelSession.Profile { Instructions("Plan the week's meals.") }
            .model(model, effort: effort)
    }
}

func planWeek() async throws -> String {
    // An OpenRouterLanguageModel<Efforts.Of<OpenRouterModels.AnthropicClaudeHaiku5_5>>: Claude Haiku 5.5's levels.
    let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, apiKey: { try await keyStore.openRouterKey() })
    let session = LanguageModelSession(profile: MealPlannerProfile(model: model, effort: .xhigh))
    return try await session.respond(to: "Plan dinners for a busy week.").content
}
// snippet.end

// snippet.hide
func appleLevel(session: LanguageModelSession) async throws {
    // snippet.show
    // snippet.request
    let response = try await session.respond(
        to: "Something quick for tonight.",
        contextOptions: ContextOptions(reasoningLevel: .light)
    )
    // snippet.end
    // snippet.hide
    _ = response
}

// snippet.show
// snippet.sessionLevel
struct BriefProfile<Model: LanguageModel>: LanguageModelSession.DynamicProfile {
    let model: Model

    var body: some LanguageModelSession.DynamicProfile {
        LanguageModelSession.Profile { Instructions("Suggest one dinner.") }
            .model(model)
            .reasoningLevel(.moderate)
    }
}
// snippet.end

// snippet.hide
func modelLevel() async throws {
    // snippet.show
    // snippet.modelLevel
    let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, apiKey: { try await keyStore.openRouterKey() })
    let session = LanguageModelSession(model: model)

    let response = try await session.respond(
        to: "Plan a month of dinners without repeating one.",
        contextOptions: ContextOptions(reasoningLevel: model.reasoningLevel(.max))
    )
    // snippet.end
    // snippet.hide
    _ = response

    // snippet.show
    // snippet.levels
    print(model.details.reasoningEfforts.map { "\($0)" })  // ["max", "xhigh", "high", "medium", "low", "none"]
    // snippet.end
    // snippet.hide
}

// snippet.show
// snippet.runtime
func session(forModelID id: OpenRouterModelID) -> LanguageModelSession? {
    guard let picked = OpenRouterModel(catalogID: id), let highest = picked.reasoningEfforts.first else { return nil }
    let model = OpenRouterLanguageModel(picked, apiKey: { try await keyStore.openRouterKey() })
    return LanguageModelSession(profile: MealPlannerProfile(model: model, effort: highest))
}
// snippet.end

// snippet.hide
/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openRouterKey() async throws -> String { "" }
}

let keyStore = KeyStore()
