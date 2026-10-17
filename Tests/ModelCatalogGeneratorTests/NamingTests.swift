import Testing

@testable import ModelCatalogGenerator

@Suite("Naming")
struct NamingTests {
    @Test(arguments: [
        ("anthropic/claude-opus-5.5", "anthropicClaudeOpus5_5"),
        ("openai/gpt-6.1-terra:batch", "openaiGpt6_1TerraBatch"),
        ("~openai/gpt-terra-latest", "openaiGptTerraLatest"),
        ("meta-llama/llama-3.1-8b-instruct", "metaLlamaLlama3_1_8bInstruct"),
        ("openai/gpt-4o", "openaiGpt4o"),
        ("01-ai/yi-large", "`01AiYiLarge`"),
        ("default", "`default`"),
    ])
    func `a model id becomes a member name`(id: String, name: String) {
        #expect(SwiftIdentifier.member(for: id) == name)
    }

    @Test(arguments: [("none", "off", "Off"), ("xhigh", "xhigh", "Xhigh"), ("max", "max", "Max")])
    func `an effort word becomes a case and a type name part`(word: String, caseName: String, typePart: String) {
        #expect(SwiftIdentifier.effortCase(for: word) == caseName)
        #expect(SwiftIdentifier.effortTypeComponent(for: word) == typePart)
    }

    @Test func `an effort set's type name lists its words highest first`() {
        #expect(EffortType.set(words: ["max", "high", "none"]).swiftName == "Efforts.MaxHighOff")
    }

    @Test func `a model's effort type follows what it reports`() {
        let ranking = ["max", "high", "low", "none"]

        #expect(
            EffortType(for: catalogModel("a", efforts: ["low", "max"], parameters: ["reasoning"]), ranking: ranking)
                == .set(words: ["max", "low"])
        )
        #expect(EffortType(for: catalogModel("b", parameters: ["reasoning"]), ranking: ranking) == .unsupported)
        #expect(EffortType(for: catalogModel("c", parameters: ["tools"]), ranking: ranking) == .unsupported)
    }
}
