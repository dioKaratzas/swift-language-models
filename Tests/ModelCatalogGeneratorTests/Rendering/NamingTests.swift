import Testing

@testable import ModelCatalogGenerator

@Suite("Naming")
struct NamingTests {
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

    @Test(arguments: [("none", "off"), ("xhigh", "xhigh"), ("max", "max")])
    func `an effort word becomes a member name`(word: String, name: String) {
        #expect(SwiftIdentifier.effortMember(for: word).description == name)
    }

    @Test(arguments: [
        ("anthropic/claude-opus-5.5", "AnthropicClaudeOpus5_5"),
        ("openai/gpt-6.1-terra:free", "OpenaiGpt6_1TerraFree"),
        ("01-ai/yi-large", "`01AiYiLarge`"),
    ])
    func `a model id becomes a type name`(id: String, name: String) {
        #expect(SwiftIdentifier.type(for: id).description == name)
    }

    @Test(arguments: [
        (catalogModel("anthropic/claude-opus-5.5", efforts: ["high"]), "Efforts.Of<OpenRouterModels.AnthropicClaudeOpus5_5>"),
        (catalogModel("vendor/plain"), "Efforts.Of<OpenRouterModels.VendorPlain>"),
    ])
    func `every model has an effort type of its own, whether or not it has levels`(model: CatalogModel, effortType: String) {
        #expect(CatalogSource.openrouter.effortType(of: model) == effortType)
    }

    @Test func `a value named twice the same way doesn't clash with itself`() throws {
        let name = SwiftIdentifier.member(for: "vendor/model")

        try SwiftIdentifier.check([(name, "vendor/model"), (name, "vendor/model")], kind: "models")
    }
}
