import Foundation

/// Stable JSON for files in `Catalogs/`.
enum CatalogJSON {
    /// The value as JSON text with sorted keys, two-space indents and a final newline, so the same value always gives
    /// the same bytes.
    static func encoded(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self) + "\n"
    }

    /// Reads a file, or returns `nil` when it doesn't exist.
    ///
    /// - Throws: An error when the file exists but can't be read or decoded.
    static func read<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}
