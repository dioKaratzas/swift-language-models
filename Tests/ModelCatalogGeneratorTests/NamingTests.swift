import Testing

@testable import ModelCatalogGenerator

@Suite("Naming")
struct NamingTests {
    private static func ranking() throws -> EffortRanking {
        try EffortRanking(bases: [["max", "high", "low", "none"]])
    }

    @Test(arguments: [
        ("anthropic/claude-opus-5.5", "anthropicClaudeOpus5_5"),
        ("openai/gpt-6.1-terra:free", "openaiGpt6_1TerraFree"),
        ("~openai/gpt-terra-latest", "openaiGptTerraLatest"),
        ("meta-llama/llama-3.1-8b-instruct", "metaLlamaLlama3_1_8bInstruct"),
        ("openai/gpt-4o", "openaiGpt4o"),
        ("01-ai/yi-large", "`01AiYiLarge`"),
        ("default", "`default`"),
        ("vendor/café-2", "vendorCaf2"),
        ("vendor/model-٣", "vendorModel"),
        ("~/-", ""),
    ])
    func `a model id becomes a member name`(id: String, name: String) {
        #expect(SwiftIdentifier.member(for: id).description == name)
    }

    @Test func `a suffix joins a name inside its backticks`() {
        #expect(SwiftIdentifier.member(for: "01-ai/yi-large").appending("Entry").description == "`01AiYiLargeEntry`")
    }

    @Test(arguments: [("none", "off", "Off"), ("xhigh", "xhigh", "Xhigh"), ("max", "max", "Max")])
    func `an effort word becomes a case and a type name`(word: String, caseName: String, typeName: String) {
        #expect(SwiftIdentifier.effortCase(for: word).description == caseName)
        #expect(SwiftIdentifier.effortType(for: [word]).description == typeName)
    }

    @Test func `an effort set's type name lists its words highest first`() throws {
        #expect(try EffortType(words: ["none", "high", "max"], ranking: Self.ranking()).swiftName == "Efforts.MaxHighOff")
    }

    @Test func `a model's effort type follows what it reports`() throws {
        let ranking = try Self.ranking()
        let reasoning = catalogModel("a", efforts: ["low", "max"], parameters: ["reasoning"])

        #expect(EffortType(for: reasoning, ranking: ranking).words == ["max", "low"])
        #expect(EffortType(for: catalogModel("b", parameters: ["reasoning"]), ranking: ranking).swiftName == "Efforts.Unsupported")
        #expect(EffortType(for: catalogModel("c", parameters: ["tools"]), ranking: ranking).swiftName == "Efforts.Unsupported")
    }

    @Test func `a value named twice the same way doesn't clash with itself`() throws {
        let name = SwiftIdentifier.member(for: "vendor/model")

        try SwiftIdentifier.check([(name, "vendor/model"), (name, "vendor/model")], kind: "models")
    }
}
