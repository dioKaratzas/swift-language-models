import Foundation

/// Stable JSON for files in `Catalogs/`.
enum CatalogJSON {
    /// The value as JSON text with sorted keys, two-space indents and a final newline, so the same value always gives
    /// the same bytes.
    ///
    /// - Throws: ``GeneratorError/invalidCatalog(_:)`` when the value can't be encoded.
    static func encoded(_ value: some Encodable) throws(GeneratorError) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            return String(decoding: try encoder.encode(value), as: UTF8.self) + "\n"
        } catch {
            throw .invalidCatalog("A catalog can't be encoded: \(error)")
        }
    }

    /// Reads a file in the package, or returns `nil` when it doesn't exist.
    ///
    /// - Parameters:
    ///   - type: The type the file holds.
    ///   - path: The file, relative to the package root.
    ///   - packageDirectory: The package root.
    /// - Throws: ``GeneratorError/fileAccess(_:)`` when the file exists but can't be read, and
    ///   ``GeneratorError/invalidCatalog(_:)`` when it doesn't decode.
    static func read<Value: Decodable>(
        _ type: Value.Type,
        at path: String,
        in packageDirectory: URL
    ) throws(GeneratorError) -> Value? {
        let data: Data
        do {
            data = try Data(contentsOf: packageDirectory.appending(path: path))
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        } catch {
            throw .fileAccess("Couldn't read \(path): \(error.localizedDescription)")
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw .invalidCatalog("\(path) doesn't decode: \(error)")
        }
    }
}
