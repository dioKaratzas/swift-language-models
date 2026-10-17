import Foundation

/// The `ModelCatalogGenerator` command-line tool.
@main
enum Generator {
    static func main() async {
        do {
            let currentDirectory = URL(filePath: FileManager.default.currentDirectoryPath, directoryHint: .isDirectory)
            guard let command = try Command.parse(Array(CommandLine.arguments.dropFirst()), currentDirectory: currentDirectory)
            else {
                print(Command.usage)
                return
            }
            try await run(command)
        } catch {
            try? FileHandle.standardError.write(contentsOf: Data("error: \(error)\n".utf8))
            exit((error as? GeneratorError)?.exitCode ?? 1)
        }
    }

    /// Runs one subcommand.
    ///
    /// - Parameters:
    ///   - command: The parsed command.
    ///   - session: The session for `fetch`.
    ///   - baseURL: Where every source's API lives, replacing each source's own address.
    ///   - today: The date recorded for removed models, as `yyyy-MM-dd`.
    static func run(
        _ command: Command,
        session: URLSession = URLSession(configuration: .ephemeral),
        baseURL: URL? = nil,
        today: String = Date.now.formatted(.iso8601.year().month().day())
    ) async throws {
        switch command.action {
        case .fetch:
            for source in command.sources {
                try await fetch(source, into: command.packageDirectory, session: session, baseURL: baseURL, today: today)
            }
        case .render:
            for file in try generatedFiles(in: command.packageDirectory) {
                try write(file.contents, to: file.path, in: command.packageDirectory)
                print("Rendered \(file.path).")
            }
        case .check:
            let stale = try generatedFiles(in: command.packageDirectory).filter { file in
                let url = command.packageDirectory.appending(path: file.path)
                return (try? String(contentsOf: url, encoding: .utf8)) != file.contents
            }
            guard stale.isEmpty else { throw GeneratorError.stale(stale.map(\.path)) }
            print("Generated files match the catalogs.")
        }
    }

    /// Updates a source's snapshot and schema, and prints how the source's list changed shape.
    ///
    /// Nothing is written unless both files can be made.
    private static func fetch(
        _ source: CatalogSource,
        into packageDirectory: URL,
        session: URLSession,
        baseURL: URL?,
        today: String
    ) async throws {
        let data = try await source.modelList(using: session, baseURL: baseURL)
        let snapshot = try CatalogSnapshot.updated(
            source: source,
            fetched: source.catalogModels(from: data),
            previous: read(CatalogSnapshot.self, at: source.snapshotPath, in: packageDirectory),
            today: today
        )
        let schema = try source.schema(of: data)
        let previousSchema = try read(CatalogSchema.self, at: source.schemaPath, in: packageDirectory)
        let snapshotText = try CatalogJSON.encoded(snapshot)
        let schemaText = try CatalogJSON.encoded(schema)

        try write(snapshotText, to: source.snapshotPath, in: packageDirectory)
        try write(schemaText, to: source.schemaPath, in: packageDirectory)
        print("Fetched \(snapshot.models.count) \(source.displayName) models into \(source.snapshotPath).")
        let changes = previousSchema.map(schema.changes(since:)) ?? []
        if !changes.isEmpty {
            print("\(source.displayName)'s model list changed shape. Review \(source.schemaPath) before releasing:")
            for change in changes { print("  \(change)") }
        }
    }

    private static func generatedFiles(in packageDirectory: URL) throws -> [GeneratedFile] {
        let snapshots = try CatalogSource.allCases.compactMap { source in
            try read(CatalogSnapshot.self, at: source.snapshotPath, in: packageDirectory)
        }
        return try CatalogRenderer.files(for: snapshots)
    }

    private static func read<Value: Decodable>(_ type: Value.Type, at path: String, in packageDirectory: URL) throws -> Value? {
        try CatalogJSON.read(type, from: packageDirectory.appending(path: path))
    }

    private static func write(_ contents: String, to path: String, in packageDirectory: URL) throws {
        let url = packageDirectory.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url, options: .atomic)
    }
}
