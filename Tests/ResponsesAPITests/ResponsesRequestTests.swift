import APIFormat
import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import ResponsesAPI

@Suite("Responses request")
struct ResponsesRequestTests {
    @Test func `the format writes its members in a fixed order, leaves out a seed and raises a token limit below 16`() throws {
        let options = GenerationOptions(
            samplingMode: .random(probabilityThreshold: 0.5, seed: 1), temperature: 0.2, maximumResponseTokens: 10)
        let request = generationRequest([prompt(text("Hi"))], options: options, metadata: ["team": "coach"])

        let sent = try ResponsesRequest(request, dialect: TestDialect())

        #expect(keys(sent.body) == ["model", "input", "stream", "temperature", "top_p", "max_output_tokens", "metadata"])
        #expect(sent.body["model"] == "vendor/model")
        #expect(sent.body["stream"] == true)
        #expect(sent.body["max_output_tokens"] == 16)
        #expect(sent.adjustments == [.unsentSettings(["seed"]), .raisedTokenLimit(requested: 10, sent: 16)])
    }

    @Test func `the dialect adds its members, in its order`() throws {
        var setup = TestModel.Setup()
        setup.plan = { _ in BodyPlan(extras: ["service_tier": "flex", "prompt_cache_key": "session"]) }

        let body = try ResponsesRequest(generationRequest([prompt(text("Hi"))]), dialect: TestDialect(setup)).body

        #expect(keys(body) == ["model", "service_tier", "input", "stream", "prompt_cache_key"])
    }

    @Test func `the plan's storage, encrypted reasoning, reasoning and text members go out in the format's places`() throws {
        var setup = TestModel.Setup()
        setup.plan = { _ in
            var plan = BodyPlan<JSONValue>(extras: [:])
            plan.storage = .notStored
            plan.asksForEncryptedReasoning = true
            plan.reasoning = .init(effort: "low", summary: "auto")
            plan.textExtras = Verbosity(verbosity: "low")
            return plan
        }
        let request = generationRequest([prompt(text("Rate it."))], schema: Rating.generationSchema)

        let body = try ResponsesRequest(request, dialect: TestDialect(setup)).body

        #expect(keys(body) == ["model", "input", "stream", "store", "include", "text", "reasoning"])
        #expect(body["store"] == false)
        #expect(body["include"] == ["reasoning.encrypted_content"])
        #expect(keys(body["text"]) == ["format", "verbosity"])
        #expect(keys(body["text"]?["format"]) == ["type", "name", "schema", "strict"])
        #expect(body["text"]?["format"]?["type"] == "json_schema")
        #expect(body["text"]?["format"]?["strict"] == true)
        #expect(body["text"]?["verbosity"] == "low")
        #expect(body["reasoning"] == ["effort": "low", "summary": "auto"])
    }

    @Test func `storage the provider keeps sends store, and the provider's default sends none`() throws {
        var setup = TestModel.Setup()
        setup.plan = { _ in
            var plan = BodyPlan<JSONValue>(extras: [:])
            plan.storage = .stored
            plan.reasoning = .init()
            return plan
        }

        let stored = try ResponsesRequest(generationRequest([prompt(text("Hi"))]), dialect: TestDialect(setup)).body
        let automatic = try ResponsesRequest(generationRequest([prompt(text("Hi"))]), dialect: TestDialect()).body

        #expect(stored["store"] == true)
        #expect(stored["reasoning"] == nil)
        #expect(automatic["store"] == nil)
    }

    @Test func `members the models don't list are left out, then settings the format has no member for`() throws {
        var setup = TestModel.Setup()
        setup.lists = { $0 == .topP }
        let options = GenerationOptions(samplingMode: .random(top: 40, seed: 3), temperature: 0.2, maximumResponseTokens: 10)

        let sent = try ResponsesRequest(generationRequest([prompt(text("Hi"))], options: options), dialect: TestDialect(setup))

        // A token limit left out isn't raised.
        #expect(keys(sent.body) == ["model", "input", "stream"])
        #expect(sent.adjustments == [.unlistedParameters(["temperature", "max_output_tokens"]), .unsentSettings(["top_k", "seed"])])
    }

    @Test func `members the plan leaves out with the request's settings are noted`() throws {
        var setup = TestModel.Setup()
        setup.plan = { _ in
            var plan = BodyPlan<JSONValue>(extras: [:])
            plan.leftOutMembers = [.temperature, .topP]
            plan.movedEffort = .init(requested: "medium", sent: "low")
            return plan
        }
        let options = GenerationOptions(temperature: 0.2)

        let sent = try ResponsesRequest(generationRequest([prompt(text("Hi"))], options: options), dialect: TestDialect(setup))

        #expect(sent.body["temperature"] == nil)
        #expect(sent.adjustments == [.unsentSettings(["temperature"]), .movedEffort(requested: "medium", sent: "low")])
    }

    @Test func `the session's tools go as functions whose arguments aren't held to the schema, with the tool choice`() throws {
        let request = generationRequest(
            [prompt(text("Hi"))], tools: [Transcript.ToolDefinition(tool: LookUpTool())],
            options: GenerationOptions(toolCallingMode: .required))

        let body = try ResponsesRequest(request, dialect: TestDialect()).body

        #expect(keys(body) == ["model", "input", "stream", "tools", "tool_choice"])
        #expect(keys(body["tools"]?[0]) == ["type", "name", "description", "parameters", "strict"])
        #expect(body["tools"]?[0]?["name"] == "lookUp")
        #expect(body["tools"]?[0]?["strict"] == false)
        #expect(body["tool_choice"] == "required")
    }

    @Test func `a plan that leaves the session's tools out sends neither tools nor tool choice`() throws {
        var setup = TestModel.Setup()
        setup.plan = { _ in
            var plan = BodyPlan<JSONValue>(extras: [:])
            plan.sessionTools = .leftOut
            return plan
        }
        let request = generationRequest(
            [prompt(text("Hi"))], tools: [Transcript.ToolDefinition(tool: LookUpTool())],
            options: GenerationOptions(toolCallingMode: .required))

        let body = try ResponsesRequest(request, dialect: TestDialect(setup)).body

        #expect(body["tools"] == nil)
        #expect(body["tool_choice"] == nil)
    }

    @Test func `a schema goes in full, with the portable schema ready, or portable from the start`() throws {
        let request = generationRequest([prompt(text("Rate it."))], schema: Rating.generationSchema)
        var setup = TestModel.Setup()
        setup.plan = { _ in
            var plan = BodyPlan<JSONValue>(extras: [:])
            plan.schema = .portable
            return plan
        }

        let full = try ResponsesRequest(request, dialect: TestDialect())
        let portable = try ResponsesRequest(request, dialect: TestDialect(setup))

        #expect(full.body["text"]?["format"]?["schema"]?["properties"]?["stars"]?["maximum"] == 5)
        #expect(full.portableSchemaBody?["text"]?["format"]?["schema"]?["properties"]?["stars"]?["maximum"] == nil)
        #expect(portable.body["text"]?["format"]?["schema"]?["properties"]?["stars"]?["maximum"] == nil)
        #expect(portable.portableSchemaBody == nil)
    }
}

/// A member a dialect adds to `text`.
private struct Verbosity: Encodable, Sendable {
    let verbosity: String
}
