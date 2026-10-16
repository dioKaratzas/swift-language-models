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
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
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
                let url = command.packageDirectory.appending(path: source.snapshotPath)
                let fetched = try await source.fetch(using: session, baseURL: baseURL)
                let snapshot = try CatalogSnapshot.updated(
                    source: source,
                    fetched: fetched,
                    previous: try CatalogSnapshot.read(from: url),
                    today: today
                )
                try write(try snapshot.encoded(), to: source.snapshotPath, in: command.packageDirectory)
                print("Fetched \(snapshot.models.count) \(source.displayName) models into \(source.snapshotPath).")
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

    private static func generatedFiles(in packageDirectory: URL) throws -> [GeneratedFile] {
        let snapshots = try CatalogSource.allCases.compactMap { source in
            try CatalogSnapshot.read(from: packageDirectory.appending(path: source.snapshotPath))
        }
        return try CatalogRenderer.files(for: snapshots)
    }

    private static func write(_ contents: String, to path: String, in packageDirectory: URL) throws {
        let url = packageDirectory.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url, options: .atomic)
    }
}
