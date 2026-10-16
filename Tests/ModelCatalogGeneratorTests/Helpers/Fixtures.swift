import Foundation
import LanguageModelsTesting

@testable import ModelCatalogGenerator

/// The six-model OpenRouter fixture, as `fetch` would store it on first run.
func fixtureSnapshot() throws -> CatalogSnapshot {
    let response = try OpenRouterModelsResponse.decoded(from: Bundle.module.fixture("openrouter-models.json"))
    return try CatalogSnapshot.updated(
        source: .openrouter,
        fetched: response.catalogModels,
        previous: nil,
        today: "2026-10-29"
    )
}

/// The text of a golden file in the fixtures folder.
func golden(_ name: String) throws -> String {
    String(decoding: try Bundle.module.fixture(name), as: UTF8.self)
}

/// A catalog model with only the facts a test cares about.
func catalogModel(
    _ id: String,
    efforts: [String] = [],
    parameters: [String] = ["tools"]
) -> CatalogModel {
    CatalogModel(
        id: id,
        displayName: id,
        releasedAt: 0,
        knowledgeCutoff: nil,
        expirationDate: nil,
        contextSize: nil,
        maximumResponseTokens: nil,
        inputModalities: ["text"],
        outputModalities: ["text"],
        supportedParameters: parameters,
        reasoningEfforts: efforts,
        defaultReasoningEffort: efforts.first,
        isReasoningMandatory: false,
        reasonsByDefault: false,
        pricing: nil
    )
}
