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
        ("openrouter/auto", "openRouterAuto"),
        ("openrouter", "openRouter"),
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
        ("openrouter/auto", "OpenRouterAuto"),
    ])
    func `a model id becomes a type name`(id: String, name: String) {
        #expect(SwiftIdentifier.member(for: id).capitalized.description == name)
    }

    @Test(arguments: [
        ("anthropicClaudeOpus5_5", "Efforts.Of<OpenRouterCatalog.AnthropicClaudeOpus5_5>"),
        ("vendorPlain_2", "Efforts.Of<OpenRouterCatalog.VendorPlain_2>"),
    ])
    func `a model's member name gives its effort type`(member: String, effortType: String) {
        #expect(CatalogSource.openrouter.effortType(named: SwiftIdentifier(name: member)) == effortType)
    }

    @Test func `a value named twice the same way doesn't clash with itself`() throws {
        let name = SwiftIdentifier.member(for: "vendor/model")

        try SwiftIdentifier.check([(name, "vendor/model"), (name, "vendor/model")], kind: "models")
    }

    @Test(arguments: [
        // A removed model takes its turn by release too.
        (
            catalogSnapshot(
                catalogModel("x/m-1-5", releasedAt: 100),
                removed: [RemovedModel(model: catalogModel("x/m-1.5", releasedAt: 200), removedOn: "2026-10-01")]),
            ["x/m-1-5": "xM1_5", "x/m-1.5": "xM1_5_2"]
        ),
        // Between listed models, the one released first keeps the name.
        (
            catalogSnapshot(catalogModel("x/m-1-5", releasedAt: 200), catalogModel("x/m-1.5", releasedAt: 100)),
            ["x/m-1-5": "xM1_5_2", "x/m-1.5": "xM1_5"]
        ),
        // Between models released together, the first id keeps the name.
        (
            catalogSnapshot(catalogModel("x/m-1.5"), catalogModel("x/m_1_5"), catalogModel("x/m-1-5")),
            ["x/m-1-5": "xM1_5", "x/m-1.5": "xM1_5_2", "x/m_1_5": "xM1_5_3"]
        ),
        // A suffix skips a name that a model before it took.
        (
            catalogSnapshot(
                catalogModel("x/m-1-5-2", releasedAt: 50), catalogModel("x/m-1-5", releasedAt: 100),
                removed: [RemovedModel(model: catalogModel("x/m-1.5", releasedAt: 200), removedOn: "2026-10-01")]
            ),
            ["x/m-1-5": "xM1_5", "x/m-1-5-2": "xM1_5_2", "x/m-1.5": "xM1_5_3"]
        ),
    ])
    func `a model whose name a model before it took gets the next numbered suffix`(
        snapshot: CatalogSnapshot,
        names: [String: String]
    ) {
        let named = snapshot.namedModels

        #expect(Dictionary(uniqueKeysWithValues: named.map { ($0.model.id, $0.name.name) }) == names)
        #expect(named.map(\.model.id) == names.keys.sorted())
    }

    @Test func `removing a model renames neither it nor a model whose name it shares`() {
        let older = catalogModel("x/m-1-5", releasedAt: 100)
        let newer = catalogModel("x/m-1.5", releasedAt: 200)
        let listed = catalogSnapshot(older, newer)
        let afterRemoval = catalogSnapshot(older, removed: [RemovedModel(model: newer, removedOn: "2026-10-01")])

        #expect(afterRemoval.namedModels.map(\.name) == listed.namedModels.map(\.name))
    }

    @Test func `the names depend on the snapshot's content, not its order, and a newer model renames nothing`() {
        let removed = [
            RemovedModel(model: catalogModel("x/m-1.5", releasedAt: 300), removedOn: "2026-10-01"),
            RemovedModel(model: catalogModel("x/m_1_5", releasedAt: 100), removedOn: "2026-10-02"),
        ]
        let models = [catalogModel("x/m-1-5", releasedAt: 200), catalogModel("y/other", releasedAt: 50)]
        let snapshot = CatalogSnapshot(source: .openrouter, models: models, removed: removed, vocabularies: [:], efforts: [])
        let reordered = CatalogSnapshot(
            source: .openrouter, models: models.reversed(), removed: removed.reversed(), vocabularies: [:], efforts: [])
        let grown = CatalogSnapshot(
            source: .openrouter, models: models + [catalogModel("x/m.1.5", releasedAt: 400)], removed: removed,
            vocabularies: [:], efforts: [])

        let names = Dictionary(uniqueKeysWithValues: snapshot.namedModels.map { ($0.model.id, $0.name) })
        let grownNames = Dictionary(uniqueKeysWithValues: grown.namedModels.map { ($0.model.id, $0.name) })

        #expect(reordered.namedModels.map(\.name) == snapshot.namedModels.map(\.name))
        #expect(names.allSatisfy { grownNames[$0.key] == $0.value })
        #expect(grownNames["x/m.1.5"]?.name == "xM1_5_4")
    }
}
