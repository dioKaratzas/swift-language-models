import Testing

@testable import ModelCatalogGenerator

@Suite("Catalog changes")
struct CatalogChangesTests {
    private static let model = catalogModel("a/model", efforts: ["high", "low"])

    @Test func `equal snapshots need no release`() {
        let snapshot = catalogSnapshot(Self.model)

        let changes = CatalogChanges(from: snapshot, to: snapshot, oldSchema: nil, newSchema: nil)

        #expect(changes.bump == .none)
        #expect(changes.members.isEmpty && changes.models.isEmpty && changes.api.isEmpty)
    }

    @Test func `a model's changed data is a patch with each field's old and new value`() {
        let old = catalogModel("a/model", displayName: "Old", parameters: ["seed", "tools"])
        let new = catalogModel("a/model", displayName: "New", parameters: ["tools", "top_k"], reasoning: .mandatory)

        let changes = CatalogChanges(from: catalogSnapshot(old), to: catalogSnapshot(new), oldSchema: nil, newSchema: nil)

        #expect(changes.bump == .patch)
        #expect(changes.members.isEmpty)
        #expect(
            changes.models == [
                CatalogChanges.ModelChange(
                    id: "a/model",
                    fields: [
                        #"displayName "Old" → "New""#, "supportedParameters adds `top_k`, drops `seed`",
                        "reasoning `unsupported` → `mandatory`",
                    ]
                )
            ]
        )
    }

    @Test(arguments: [
        (catalogSnapshot(model), catalogSnapshot(model, catalogModel("b/new")), CatalogChanges.Bump.minor, "Adds `b/new`."),
        (
            catalogSnapshot(model), catalogSnapshot(catalogModel("a/model", efforts: ["high", "low"], expirationDate: "2026-12-01")),
            .minor, "Deprecates `a/model`: OpenRouter retires it on 2026-12-01."
        ),
        (
            catalogSnapshot(model), catalogSnapshot(removed: [RemovedModel(model: model, removedOn: "2026-10-31")]),
            .minor, "Marks `a/model` unavailable: OpenRouter stopped listing it on 2026-10-31."
        ),
        (
            catalogSnapshot(removed: [RemovedModel(model: model, removedOn: "2026-10-31")]), catalogSnapshot(model),
            .minor, "Brings back `a/model`: OpenRouter lists it again."
        ),
        (catalogSnapshot(model), catalogSnapshot(), .major, "Deletes `a/model`."),
        (
            catalogSnapshot(model), catalogSnapshot(catalogModel("a/model", efforts: ["xhigh", "high", "low"])),
            .minor, "`a/model` gains the effort levels `xhigh`."
        ),
        (
            catalogSnapshot(model), catalogSnapshot(catalogModel("a/model", efforts: ["high"])),
            .major, "`a/model` loses the effort levels `low`."
        ),
    ])
    func `each change to the models needs its release`(
        old: CatalogSnapshot,
        new: CatalogSnapshot,
        bump: CatalogChanges.Bump,
        summary: String
    ) {
        let changes = CatalogChanges(from: old, to: new, oldSchema: nil, newSchema: nil)

        #expect(changes.bump == bump)
        #expect(changes.members == [CatalogChanges.MemberChange(bump: bump, summary: summary)])
    }

    @Test(arguments: [
        ([], [CatalogWord("seed")], CatalogChanges.Bump.minor, "Adds the `parameters` word `seed`."),
        (
            [CatalogWord("seed")], [CatalogWord("seed", removedOn: "2026-10-31")], .minor,
            "Marks the `parameters` word `seed` unavailable: OpenRouter dropped it."
        ),
        ([CatalogWord("seed", removedOn: "2026-10-31")], [CatalogWord("seed")], .minor, "Brings back the `parameters` word `seed`."),
        ([CatalogWord("seed")], [], .major, "Deletes the `parameters` word `seed`."),
        (
            [CatalogWord("seed", summary: "Old.")], [CatalogWord("seed", summary: "New.")], .patch,
            "Rewords the summary of the `parameters` word `seed`."
        ),
    ])
    func `each change to a vocabulary needs its release`(
        old: [CatalogWord],
        new: [CatalogWord],
        bump: CatalogChanges.Bump,
        summary: String
    ) {
        let changes = CatalogChanges(
            from: catalogSnapshot(vocabularies: [.parameters: old]),
            to: catalogSnapshot(vocabularies: [.parameters: new]),
            oldSchema: nil,
            newSchema: nil
        )

        #expect(changes.bump == bump)
        #expect(changes.members == [CatalogChanges.MemberChange(bump: bump, summary: summary)])
    }

    @Test func `a change only to the API's shape is reported and releases nothing`() {
        let snapshot = catalogSnapshot(Self.model)
        let oldSchema = CatalogSchema(fields: ["data[].id", "data[].pricing.prompt"], values: [:])
        let newSchema = CatalogSchema(fields: ["data[].endpoints[]", "data[].id"], values: [:])

        let changes = CatalogChanges(from: snapshot, to: snapshot, oldSchema: oldSchema, newSchema: newSchema)

        #expect(changes.bump == .none)
        #expect(changes.api == ["Adds the field `data[].endpoints[]`.", "Drops the field `data[].pricing.prompt`."])
    }

    @Test func `the changelog leads with the release and groups the changes`() {
        let changes = CatalogChanges(
            from: catalogSnapshot(catalogModel("a/model", displayName: "Old")),
            to: catalogSnapshot(catalogModel("a/model", displayName: "New"), catalogModel("b/new")),
            oldSchema: CatalogSchema(fields: ["data[].id"], values: [:]),
            newSchema: CatalogSchema(fields: ["data[].endpoints[]", "data[].id"], values: [:])
        )

        #expect(
            [changes].changelog == """
                **Release:** `minor`

                ### OpenRouter models and words

                - Adds `b/new`.

                ### OpenRouter model data

                - `a/model`: displayName "Old" → "New".

                ### OpenRouter API shape

                - Adds the field `data[].endpoints[]`.

                """
        )
    }

    @Test func `the release of several sources is the largest one`() {
        let patch = CatalogChanges(source: .openrouter, members: [], models: [], api: [], bump: .patch)
        let major = CatalogChanges(source: .openrouter, members: [], models: [], api: [], bump: .major)

        #expect([patch, major].bump == .major)
        #expect([CatalogChanges]().bump == .none)
    }
}
