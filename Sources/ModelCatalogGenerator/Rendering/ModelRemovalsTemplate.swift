/// Renders the models a source stopped listing, each with the day it left, as a static member of `ModelRemovals`,
/// which the source's details read for their removal date.
enum ModelRemovalsTemplate {
    /// Where the source's generated file goes.
    static func path(for source: CatalogSource) -> String {
        "\(source.generatedDirectory)/ModelRemovals+\(source.swiftName).swift"
    }

    static func render(_ snapshot: CatalogSnapshot) -> GeneratedFile {
        let source = snapshot.source
        let removed = snapshot.removed.sorted { $0.model.id < $1.model.id }
        let member = source.swiftName.prefix(1).lowercased() + source.swiftName.dropFirst()

        var lines = SourceText.header(from: [source])
        lines += [
            "import Foundation", "import LanguageModels", "", "extension ModelRemovals {",
            "    /// The models \(source.displayName) stopped listing, which its catalog keeps as deprecated members.",
        ]
        if removed.isEmpty {
            lines += ["    static let \(member) = ModelRemovals([:])"]
        } else {
            lines += ["    static let \(member) = ModelRemovals(["]
            lines += removed.map { "        \(SwiftLiteral.string($0.model.id)): \(SwiftLiteral.date($0.removedOn))," }
            lines += ["    ])"]
        }
        lines += ["}"]
        return GeneratedFile(path: path(for: source), contents: SourceText.file(lines))
    }
}
