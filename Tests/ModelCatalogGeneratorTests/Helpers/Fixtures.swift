import Foundation
import LanguageModelsTesting

@testable import ModelCatalogGenerator

/// The OpenRouter fixture: eight real models, some edited to cover more cases, and a trimmed API description.
func fixtureDocuments() throws -> CatalogDocuments {
    CatalogDocuments(
        modelList: try Bundle.module.fixture("openrouter-models.json"),
        apiDescription: try Bundle.module.fixture("openrouter-openapi.json")
    )
}

/// The OpenRouter fixture, as `fetch` would store it on first run.
func fixtureSnapshot() throws -> CatalogSnapshot {
    try CatalogSnapshot.updated(
        source: .openrouter,
        fetched: CatalogSource.openrouter.catalog(from: fixtureDocuments()),
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
    defaultEffort: String? = nil,
    parameters: [String] = ["tools"],
    expirationDate: String? = nil,
    pricing: CatalogModel.Pricing? = nil
) -> CatalogModel {
    CatalogModel(
        id: id,
        displayName: id,
        aliasTarget: nil,
        releasedAt: 0,
        knowledgeCutoff: nil,
        expirationDate: expirationDate,
        contextSize: nil,
        maximumResponseTokens: nil,
        inputModalities: ["text"],
        outputModalities: ["text"],
        supportedParameters: parameters,
        reasoningEfforts: efforts,
        defaultReasoningEffort: defaultEffort ?? efforts.first,
        isReasoningMandatory: false,
        reasonsByDefault: false,
        pricing: pricing
    )
}
