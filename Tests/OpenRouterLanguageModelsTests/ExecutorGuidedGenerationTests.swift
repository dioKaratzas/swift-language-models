import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: guided generation")
struct ExecutorGuidedGenerationTests {
    @Test func `a model with structured outputs gets a strict schema`() async throws {
        let stub = HTTPStub(events(text(#"{"name":"So"#), text(#"up","servings":2}"#), done()))
        let session = LanguageModelSession(model: model(stub))

        let meal = try await session.respond(to: "A dinner idea.", generating: Meal.self).content

        #expect(meal.name == "Soup")
        #expect(meal.servings == 2)
        let format = try body(stub)["response_format"]
        #expect(format?["type"] == "json_schema")
        #expect(format?["json_schema"]?["name"] == "Meal")
        #expect(format?["json_schema"]?["strict"] == true)
        #expect(format?["json_schema"]?["schema"]?["required"] == ["name", "servings", "notes"])
    }

    @Test(arguments: [OpenRouterModelID("anthropic/claude-haiku-5.5"), "~anthropic/claude-haiku-latest"])
    func `an Anthropic model's schema carries the constraints Anthropic rejects in its descriptions`(id: OpenRouterModelID) async throws {
        let stub = HTTPStub(events(text(Recipe.answer), done()))
        let session = LanguageModelSession(model: model(stub, id: id))

        _ = try await session.respond(to: "A recipe.", generating: Recipe.self)

        let schema = try #require(try body(stub)["response_format"]?["json_schema"]?["schema"])
        let servings = schema["properties"]?["servings"]
        #expect(servings == ["description": "How many it serves.\n\n{maximum: 12, minimum: 1}", "type": "integer"])
        #expect(schema["properties"]?["name"]?["anyOf"]?[0] == ["description": #"{pattern: "[A-Z].*"}"#, "type": "string"])
        let steps = schema["properties"]?["steps"]
        #expect(steps?["minItems"] == 1)
        #expect(steps?["maxItems"] == nil)
        #expect(steps?["description"] == "{maxItems: 5}")
        let grams = schema["$defs"]?["Ingredient"]?["properties"]?["grams"]
        #expect(grams == ["description": "{minimum: 1}", "type": "integer"])
        #expect(schema["properties"]?["ingredients"]?["description"] == "{maxItems: 3, minItems: 3}")
    }

    @Test func `another model's schema keeps its constraints`() async throws {
        let stub = HTTPStub(events(text(Recipe.answer), done()))
        let session = LanguageModelSession(model: model(stub, id: "openai/gpt-5"))

        _ = try await session.respond(to: "A recipe.", generating: Recipe.self)

        let schema = try #require(try body(stub)["response_format"]?["json_schema"]?["schema"])
        #expect(
            schema["properties"]?["servings"] == ["description": "How many it serves.", "maximum": 12, "minimum": 1, "type": "integer"]
        )
        #expect(schema["properties"]?["steps"]?["maxItems"] == 5)
    }

    @Test func `a model with only JSON mode gets the schema in the prompt that asked for it`() async throws {
        let stub = HTTPStub(events(text(#"{"name":"Soup","servings":2}"#), done()))
        let session = LanguageModelSession(model: model(stub, parameters: [.responseFormat]))

        _ = try await session.respond(to: "A dinner idea.", generating: Meal.self)

        let body = try body(stub)
        #expect(body["response_format"] == ["type": "json_object"])
        let prompt = try #require(messages(body).last)
        guard case .array(let parts)? = prompt["content"] else {
            Issue.record("The prompt has no parts: \(prompt)")
            return
        }
        #expect(parts.first?["text"] == "A dinner idea.")
        #expect(parts.last?["text"]?.stringValue?.hasPrefix("Respond with JSON that matches this JSON Schema:") == true)
    }

    @Test func `JSON mode's streamed answer becomes the generated value`() async throws {
        let stub = HTTPStub(events(text(#"{"name":"So"#), text(#"up","servings":"#), text(#"2,"notes":null}"#), done()))
        let session = LanguageModelSession(model: model(stub, parameters: [.responseFormat]))

        var snapshots: [Meal.PartiallyGenerated] = []
        for try await snapshot in session.streamResponse(to: "A dinner idea.", generating: Meal.self) {
            snapshots.append(snapshot.content)
        }

        let meal = try #require(snapshots.last)
        #expect(meal.name == "Soup")
        #expect(meal.servings == 2)
        #expect(meal.notes == nil)
        // Every snapshot's name is the start of the final one.
        #expect(snapshots.allSatisfy { "Soup".hasPrefix($0.name ?? "") })
    }

    @Test func `a model without JSON mode or structured outputs is refused before any request`() async throws {
        let stub = HTTPStub(events(text(#"{"name":"Soup","servings":2}"#), done()))
        let session = LanguageModelSession(model: model(stub, parameters: [.maxTokens]))

        let error = try await #require(throws: LanguageModelError.self) {
            try await session.respond(to: "A dinner idea.", generating: Meal.self)
        }

        guard case .unsupportedCapability = error else {
            Issue.record("Expected an unsupported capability, got \(error)")
            return
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func `JSON that doesn't match the schema throws`() async throws {
        let stub = HTTPStub(events(text(#"{"name":3}"#), done()))
        let session = LanguageModelSession(model: model(stub, parameters: [.responseFormat]))

        await #expect(throws: (any Error).self) {
            try await session.respond(to: "A dinner idea.", generating: Meal.self)
        }
    }
}

/// A recipe with the guides that become JSON Schema constraints.
@Generable
private struct Recipe {
    @Guide(.pattern(/[A-Z].*/))
    var name: String?

    @Guide(description: "How many it serves.", .range(1...12))
    var servings: Int

    @Guide(.count(1...5))
    var steps: [String]

    @Guide(.count(3))
    var ingredients: [Ingredient]

    /// An answer that matches the schema.
    static let answer =
        #"{"name":"Soup","servings":2,"steps":["Boil."],"ingredients":[{"grams":200},{"grams":10},{"grams":5}]}"#
}

@Generable
private struct Ingredient {
    @Guide(.minimum(1))
    var grams: Int
}

@Generable
private struct Meal {
    var name: String
    var servings: Int
    var notes: String?
}
