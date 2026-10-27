import Foundation
import LanguageModelsTestSupport
import Testing

@testable import ModelCatalogGenerator

extension CatalogDay: ExpressibleByStringLiteral {
    /// A day that a test writes as `yyyy-MM-dd`, or the earliest day, with an issue recorded, when the text isn't a
    /// real day.
    init(stringLiteral text: String) {
        guard let day = CatalogDay(text) else {
            Issue.record("'\(text)' isn't a day written as yyyy-MM-dd.")
            self.init(containing: .distantPast)
            return
        }
        self = day
    }
}

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

/// An OpenRouter snapshot with only the facts a test cares about.
func catalogSnapshot(
    _ models: CatalogModel...,
    removed: [RemovedModel] = [],
    vocabularies: [CatalogVocabulary: [CatalogWord]] = [:],
    efforts: [CatalogWord] = [],
    effortSets: [CatalogEffortSet] = []
) -> CatalogSnapshot {
    CatalogSnapshot(
        source: .openrouter,
        models: models,
        removed: removed,
        vocabularies: vocabularies,
        efforts: efforts,
        effortSets: effortSets
    )
}

/// A catalog model with only the facts a test cares about.
func catalogModel(
    _ id: String,
    displayName: String? = nil,
    aliasTarget: String? = nil,
    efforts: [String] = [],
    defaultEffort: String? = nil,
    parameters: [String] = ["tools"],
    outputModalities: [String] = ["text"],
    expirationDate: CatalogDay? = nil,
    reasoning: CatalogReasoning = .unsupported,
    pricing: CatalogModel.Pricing? = nil
) -> CatalogModel {
    CatalogModel(
        id: id,
        displayName: displayName ?? id,
        aliasTarget: aliasTarget,
        releasedAt: 0,
        knowledgeCutoff: nil,
        expirationDate: expirationDate,
        contextSize: nil,
        maximumOutputTokens: nil,
        inputModalities: ["text"],
        outputModalities: outputModalities,
        supportedParameters: parameters,
        reasoningEfforts: efforts,
        defaultReasoningEffort: defaultEffort ?? efforts.first,
        reasoning: reasoning,
        pricing: pricing
    )
}
