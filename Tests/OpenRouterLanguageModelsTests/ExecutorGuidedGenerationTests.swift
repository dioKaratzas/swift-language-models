import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTesting
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
}

@Generable
private struct Meal {
    var name: String
    var servings: Int
    var notes: String?
}
