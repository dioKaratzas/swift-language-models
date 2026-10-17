import Foundation
import Testing

@testable import ModelCatalogGenerator

@Suite("OpenRouter source")
struct OpenRouterSourceTests {
    private static let everyEffort = ["max", "high", "medium", "low", "none"]

    @Test func `a model that doesn't list its efforts gets none`() throws {
        let model = try catalogModel(reasoning: #"{"mandatory": false, "default_effort": "high"}"#)

        #expect(model.reasoningEfforts.isEmpty)
        #expect(model.defaultReasoningEffort == nil)
    }

    @Test func `a model that accepts every effort lists them all`() throws {
        let model = try catalogModel(reasoning: #"{"mandatory": false, "supported_efforts": null, "default_effort": "medium"}"#)

        #expect(model.reasoningEfforts == Self.everyEffort)
        #expect(model.defaultReasoningEffort == "medium")
    }

    @Test func `a model whose reasoning is mandatory never takes none`() throws {
        let model = try catalogModel(reasoning: #"{"mandatory": true, "supported_efforts": ["high", "none"], "default_effort": "none"}"#)

        #expect(model.reasoningEfforts == ["high"])
        #expect(model.defaultReasoningEffort == nil)
        #expect(model.reasoning == .mandatory)
    }

    @Test func `a default effort the model doesn't list is dropped`() throws {
        let model = try catalogModel(reasoning: #"{"mandatory": false, "supported_efforts": ["high", "low"], "default_effort": "medium"}"#)

        #expect(model.defaultReasoningEffort == nil)
    }

    @Test func `an alias keeps the id of the model it points to`() throws {
        let model = try catalogModel(fields: #""alias_target": {"name": "Vendor: Model 2", "slug": "vendor/model-2"}"#)

        #expect(model.aliasTarget == "vendor/model-2")
    }

    @Test func `an override keeps its conditions and the prices the catalog keeps`() throws {
        let pricing = #"""
            "pricing": {"prompt": "0.000001", "completion": "0.000005", "overrides": [
                {"min_prompt_tokens": 272000.5, "utc_days": ["monday"], "utc_start": 100, "utc_end": 400, "prompt": "0.000002"},
                {"min_prompt_tokens": 128000, "audio": "0.00001"}
            ]}
            """#

        let overrides = try #require(try catalogModel(fields: pricing).pricing?.overrides)

        #expect(
            overrides == [
                CatalogModel.Pricing.Override(
                    promptTokensAbove: 272_000,
                    weekdays: ["monday"],
                    startTime: 100,
                    endTime: 400,
                    prompt: "0.000002",
                    completion: nil,
                    cacheRead: nil,
                    cacheWrite: nil
                )
            ]
        )
    }

    @Test func `the API description gives the vocabularies, summaries and efforts`() throws {
        let description = try OpenRouterAPIDescription.decoded(
            from: Data(
                #"""
                {"components": {"schemas": {
                    "Parameter": {"enum": ["seed", "tool_choice", "verbosity"]},
                    "InputModality": {"enum": ["text", "image"]},
                    "OutputModality": {"enum": ["text"]},
                    "ReasoningEffort": {"enum": ["high", "low", null]},
                    "ChatRequest": {"properties": {
                        "seed": {"description": "Random seed\n  for outputs"},
                        "tool_choice": {"$ref": "#/components/schemas/ChatToolChoice"}
                    }},
                    "ChatToolChoice": {"description": "Which tool to call?"},
                    "Order": {"enum": [1, 2]}
                }}}
                """#.utf8
            )
        )

        #expect(try description.efforts() == ["high", "low"])
        #expect(
            try description.vocabularies() == [
                .inputModalities: [CatalogWord("text"), CatalogWord("image")],
                .outputModalities: [CatalogWord("text")],
                .parameters: [
                    CatalogWord("seed", summary: "Random seed for outputs."),
                    CatalogWord("tool_choice", summary: "Which tool to call?"),
                    CatalogWord("verbosity"),
                ],
            ]
        )
    }

    @Test func `an API description without a vocabulary fails`() throws {
        let documents = CatalogDocuments(
            modelList: try fixtureDocuments().modelList, apiDescription: Data(#"{"components": {"schemas": {}}}"#.utf8))

        #expect(throws: GeneratorError.self) {
            try CatalogSource.openrouter.catalog(from: documents)
        }
    }

    private func catalogModel(reasoning: String? = nil, fields: String? = nil) throws -> CatalogModel {
        let model = [
            #""id": "vendor/model", "name": "Model", "created": 0"#,
            #""architecture": {"input_modalities": ["text"], "output_modalities": ["text"]}"#,
            #""supported_parameters": ["reasoning"]"#,
            reasoning.map { #""reasoning": \#($0)"# },
            fields,
        ]
        let json = #"{"data": [{\#(model.compactMap(\.self).joined(separator: ", "))}]}"#
        let response = try OpenRouterModelsResponse.decoded(from: Data(json.utf8))
        return try #require(response.catalogModels(everyEffort: Self.everyEffort).first)
    }
}
