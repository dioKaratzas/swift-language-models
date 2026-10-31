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
        (catalogSnapshot(model), catalogSnapshot(model, catalogModel("b/new")), CatalogChanges.Bump.patch, "Adds `b/new`."),
        (
            catalogSnapshot(model), catalogSnapshot(catalogModel("a/model", efforts: ["high", "low"], expirationDate: "2026-12-01")),
            .patch, "Deprecates `a/model`: OpenRouter retires it on 2026-12-01."
        ),
        (
            catalogSnapshot(model), catalogSnapshot(removed: [RemovedModel(model: model, removedOn: "2026-10-31")]),
            .patch, "Deprecates `a/model` as removed: OpenRouter stopped listing it on 2026-10-31."
        ),
        (
            catalogSnapshot(removed: [RemovedModel(model: model, removedOn: "2026-10-31")]), catalogSnapshot(model),
            .patch, "Brings back `a/model`: OpenRouter lists it again."
        ),
        (catalogSnapshot(model), catalogSnapshot(), .major, "Deletes `a/model`."),
        (
            catalogSnapshot(model), catalogSnapshot(catalogModel("a/model", efforts: ["xhigh", "high", "low"])),
            .patch, "`a/model` gains the effort levels `xhigh`."
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
        ([], [CatalogWord("seed")], CatalogChanges.Bump.patch, "Adds the `parameters` word `seed`."),
        (
            [CatalogWord("seed")], [CatalogWord("seed", removedOn: "2026-10-31")], .patch,
            "Deprecates the `parameters` word `seed` as removed: OpenRouter stopped listing it."
        ),
        ([CatalogWord("seed", removedOn: "2026-10-31")], [CatalogWord("seed")], .patch, "Brings back the `parameters` word `seed`."),
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

    @Test func `a model listed again without a level it had when it left needs a major release`() {
        let removed = RemovedModel(model: catalogModel("a/model", efforts: ["high", "low"]), removedOn: "2026-10-31")

        let changes = CatalogChanges(
            from: catalogSnapshot(removed: [removed]),
            to: catalogSnapshot(catalogModel("a/model", efforts: ["high"])),
            oldSchema: nil,
            newSchema: nil
        )

        #expect(changes.bump == .major)
        #expect(
            changes.members == [
                CatalogChanges.MemberChange(bump: .patch, summary: "Brings back `a/model`: OpenRouter lists it again."),
                CatalogChanges.MemberChange(bump: .major, summary: "`a/model` loses the effort levels `low`."),
            ]
        )
    }

    @Test(arguments: [
        (
            catalogSnapshot(efforts: [CatalogWord("max")]), catalogSnapshot(efforts: [CatalogWord("max", removedOn: "2026-10-31")]),
            CatalogChanges.Bump.patch, "Deprecates the effort `max` as removed: OpenRouter stopped listing it."
        ),
        (catalogSnapshot(efforts: [CatalogWord("max")]), catalogSnapshot(), .major, "Deletes the effort `max`."),
        (
            catalogSnapshot(effortSets: [CatalogEffortSet(["high", "low"])]),
            catalogSnapshot(effortSets: [CatalogEffortSet(["high", "low"], removedOn: "2026-10-31")]),
            .patch, "Deprecates the effort set `high low` as removed: OpenRouter stopped listing it."
        ),
        (
            catalogSnapshot(effortSets: [CatalogEffortSet(["high", "low"])]), catalogSnapshot(), .major,
            "Deletes the effort set `high low`."
        ),
    ])
    func `each change to the efforts needs its release`(
        old: CatalogSnapshot,
        new: CatalogSnapshot,
        bump: CatalogChanges.Bump,
        summary: String
    ) {
        let changes = CatalogChanges(from: old, to: new, oldSchema: nil, newSchema: nil)

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
                **Release:** `patch`

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
