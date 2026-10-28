import Foundation
import Testing

@testable import ModelCatalogGenerator

@Suite("Catalog schema")
struct CatalogSchemaTests {
    private static let list = #"""
        {"data": [
            {"id": "a", "flags": {"free": false}, "tags": ["text", "image"], "note": null},
            {"id": "b", "pricing": {"prompt": "0.1"}, "tags": ["text"], "items": [{"kind": "x"}]}
        ]}
        """#

    @Test func `every field with a value becomes a path`() throws {
        let schema = try schema(of: Self.list)

        #expect(
            schema.fields == [
                "data[].flags.free", "data[].id", "data[].items[].kind", "data[].pricing.prompt", "data[].tags[]",
            ]
        )
    }

    @Test func `only vocabulary fields collect their words`() throws {
        #expect(try schema(of: Self.list).values == ["data[].tags[]": ["image", "text"]])
    }

    @Test func `an unchanged list reports nothing`() throws {
        #expect(try schema(of: Self.list).changes(since: schema(of: Self.list)).isEmpty)
    }

    @Test func `added and removed fields and words are reported`() throws {
        let previous = try schema(of: Self.list)
        let current = try schema(
            of: #"{"data": [{"id": "a", "flags": {"free": false}, "video": "yes", "tags": ["text", "audio"]}]}"#
        )

        #expect(
            current.changes(since: previous) == [
                "+ field data[].video",
                "- field data[].items[].kind",
                "- field data[].pricing.prompt",
                #"+ value "audio" in data[].tags[]"#,
                #"- value "image" in data[].tags[]"#,
            ]
        )
    }

    private func schema(of json: String) throws -> CatalogSchema {
        try CatalogSchema(json: Data(json.utf8), vocabularyFields: ["data[].tags[]"])
    }
}
