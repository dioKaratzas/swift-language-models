import Foundation

/// The shape of a source's raw model list: every field it uses and the words of its vocabulary fields.
///
/// `Catalogs/<source>.schema.json` stores it. The file changes only when the source adds or drops a field or a
/// vocabulary word, so its diff flags API changes the decoder would otherwise ignore.
struct CatalogSchema: Codable, Equatable, Sendable {
    /// Every path that holds a value somewhere in the list, sorted. Array elements are written `[]`, as in
    /// `data[].pricing.prompt`. Fields that are only ever `null` don't count.
    let fields: [String]

    /// The distinct words of each vocabulary field, sorted.
    let values: [String: [String]]

    /// The shape of a raw JSON document.
    ///
    /// - Parameters:
    ///   - data: The document.
    ///   - vocabularyFields: The paths whose string values to collect.
    /// - Throws: An error when `data` isn't JSON.
    init(json data: Data, vocabularyFields: Set<String>) throws {
        var fields: Set<String> = []
        var values: [String: Set<String>] = [:]
        func walk(_ value: Any, at path: String) {
            switch value {
            case let object as [String: Any]:
                for (key, child) in object { walk(child, at: path.isEmpty ? key : "\(path).\(key)") }
            case let array as [Any]:
                for element in array { walk(element, at: "\(path)[]") }
            case is NSNull:
                break
            default:
                fields.insert(path)
                if vocabularyFields.contains(path), let word = value as? String { values[path, default: []].insert(word) }
            }
        }
        walk(try JSONSerialization.jsonObject(with: data), at: "")
        self.fields = fields.sorted()
        self.values = values.mapValues { $0.sorted() }
    }

    /// What changed since an earlier schema, one line per added or removed field or word.
    func changes(since previous: CatalogSchema) -> [String] {
        func difference(_ old: [String], _ new: [String], _ describe: (String) -> String) -> [String] {
            Set(new).subtracting(old).sorted().map { "+ \(describe($0))" }
                + Set(old).subtracting(new).sorted().map { "- \(describe($0))" }
        }
        let fieldChanges = difference(previous.fields, fields) { "field \($0)" }
        let valueChanges = Set(values.keys).union(previous.values.keys).sorted().flatMap { field in
            difference(previous.values[field] ?? [], values[field] ?? []) { "value \"\($0)\" in \(field)" }
        }
        return fieldChanges + valueChanges
    }
}
