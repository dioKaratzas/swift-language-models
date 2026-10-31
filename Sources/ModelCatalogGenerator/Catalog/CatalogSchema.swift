import Foundation

/// The shape of a source's API: every field its raw model list uses, and the words of its vocabulary fields.
///
/// `Catalogs/<source>.schema.json` stores it. The file changes only when the source adds or drops a field or a
/// vocabulary word, so its diff flags API changes the decoder would otherwise ignore.
struct CatalogSchema: Codable, Equatable, Sendable {
    /// Every path that holds a value somewhere in the list, sorted. Array elements are written `[]`, as in
    /// `data[].pricing.prompt`. Fields that are only ever `null` don't count.
    let fields: [String]

    /// The distinct words of each vocabulary field, sorted.
    let values: [String: [String]]
}

extension CatalogSchema {
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

    /// What changed since an earlier schema, one sentence per added or dropped field or word.
    func changes(since previous: CatalogSchema) -> [String] {
        let addedFields = Set(fields).subtracting(previous.fields).sorted().map { "Adds the field `\($0)`." }
        let droppedFields = Set(previous.fields).subtracting(fields).sorted().map { "Drops the field `\($0)`." }
        let valueChanges = Set(values.keys).union(previous.values.keys).sorted().flatMap { field in
            let old = previous.values[field] ?? []
            let new = values[field] ?? []
            return Set(new).subtracting(old).sorted().map { "Adds the value `\($0)` to `\(field)`." }
                + Set(old).subtracting(new).sorted().map { "Drops the value `\($0)` from `\(field)`." }
        }
        return addedFields + droppedFields + valueChanges
    }
}
