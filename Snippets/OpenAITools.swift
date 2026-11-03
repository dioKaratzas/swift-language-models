// snippet.hide
import FoundationModels
import OpenAILanguageModels

func capabilities() {
    // snippet.show
    // snippet.capabilities
    print(OpenAIModel.gpt6Luna.capabilities.contains(.toolCalling))  // true
    print(OpenAIModel.gpt6Luna.capabilities.contains(.guidedGeneration))  // true
    print(OpenAIModel.gpt5_2Pro.capabilities.contains(.guidedGeneration))  // false: it doesn't list `structured_outputs`
    // snippet.end
}

// snippet.show
// snippet.feature
@Generable
struct Dinner {
    @Guide(description: "The dish's name.")
    var name: String

    @Guide(description: "The minutes it takes to cook.", .range(5...120))
    var minutes: Int
}

func suggestDinner(using model: some LanguageModel) async throws -> Dinner {
    let session = LanguageModelSession(model: model, tools: [RecipeSearch()], instructions: "Suggest one dinner.")
    return try await session.respond(to: "Something with lentils.", generating: Dinner.self).content
}
// snippet.end

// snippet.hide
/// Finds recipes in the app's own collection.
struct RecipeSearch: Tool {
    let name = "searchRecipes"
    let description = "Finds recipes that use an ingredient."

    @Generable
    struct Arguments {
        @Guide(description: "An ingredient the recipe uses.")
        var ingredient: String
    }

    func call(arguments: Arguments) async throws -> String {
        "Lentil soup with carrots and cumin, 30 minutes."
    }
}

func required(session: LanguageModelSession) async throws {
    // snippet.show
    // snippet.required
    do {
        let response = try await session.respond(
            to: "Find a recipe with lentils.",
            options: GenerationOptions(toolCallingMode: .required)
        )
        print(response.content)
    } catch LanguageModelError.unsupportedCapability(let unsupported) {
        print("The model can't be made to call a tool:", unsupported.debugDescription)
    }
    // snippet.end
    // snippet.hide
}
