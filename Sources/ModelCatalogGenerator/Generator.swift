import Foundation

/// The `ModelCatalogGenerator` command-line tool.
@main
enum Generator {
    /// What a fetch got from one source, before anything is written.
    private struct Fetch {
        let snapshot: CatalogSnapshot
        let schema: CatalogSchema
        let previousSchema: CatalogSchema?
    }

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
            exit(error.exitCode)
        }
    }

    /// Runs one subcommand.
    ///
    /// - Parameters:
    ///   - command: The parsed command.
    ///   - session: The session for `fetch`.
    ///   - baseURL: Where every source's API lives, replacing each source's own address.
    ///   - today: The day recorded for removed models.
    ///   - log: Where progress messages go.
    /// - Throws: The ``GeneratorError`` that ended the run.
    static func run(
        _ command: Command,
        session: URLSession = URLSession(configuration: .ephemeral),
        baseURL: URL? = nil,
        today: CatalogDay = CatalogDay(containing: .now),
        log: (String) -> Void = { print($0) }
    ) async throws(GeneratorError) {
        let packageDirectory = command.packageDirectory
        switch command.action {
        case .fetch:
            try await fetch(command.sources, into: packageDirectory, session: session, baseURL: baseURL, today: today, log: log)
        case .render:
            var changed = false
            for file in try generatedFiles(in: packageDirectory) {
                guard try write(file, in: packageDirectory) else { continue }
                log("Rendered \(file.path).")
                changed = true
            }
            if !changed { log("Generated files are up to date.") }
        case .check:
            let stale = try generatedFiles(in: packageDirectory).filter { file in
                (try? String(contentsOf: packageDirectory.appending(path: file.path), encoding: .utf8)) != file.contents
            }
            guard stale.isEmpty else { throw .stale(stale.map(\.path)) }
            log("Generated files match the catalogs.")
        case .diff:
            let base = try GitRevision(command.base ?? "HEAD", in: packageDirectory)
            let changes = try changes(since: base, in: packageDirectory)
            _ = try write(GeneratedFile(path: changelogPath, contents: changes.changelog), in: packageDirectory)
            _ = try write(GeneratedFile(path: reportPath, contents: try CatalogJSON.encoded(Report(changes))), in: packageDirectory)
            let release = changes.bump == .none ? "no release" : "a \(changes.bump.rawValue) release"
            log("The catalogs' changes since \(base.ref) need \(release). See \(changelogPath).")
        }
    }

    /// The Markdown changelog that `diff` writes, relative to the package root.
    static let changelogPath = ".build/catalog/CHANGELOG.md"

    /// The JSON report that `diff` writes, relative to the package root.
    static let reportPath = ".build/catalog/report.json"

    /// What `diff` reports to a workflow: the release, and each source's changes.
    struct Report: Codable, Equatable {
        let bump: CatalogChanges.Bump
        let sources: [CatalogChanges]

        init(_ changes: [CatalogChanges]) {
            bump = changes.bump
            sources = changes
        }
    }

    /// Each source's changes between a revision and the package's files.
    private static func changes(since base: GitRevision, in packageDirectory: URL) throws(GeneratorError) -> [CatalogChanges] {
        func atBase<Value: Decodable>(_ type: Value.Type, _ path: String) throws(GeneratorError) -> Value? {
            guard let data = try base.contents(of: path) else { return nil }
            return try CatalogJSON.decode(type, from: data, path: "\(path) at \(base.ref)")
        }
        var changes: [CatalogChanges] = []
        for source in CatalogSource.allCases {
            guard let snapshot = try CatalogJSON.read(CatalogSnapshot.self, at: source.snapshotPath, in: packageDirectory) else {
                continue
            }
            changes.append(
                CatalogChanges(
                    from: try atBase(CatalogSnapshot.self, source.snapshotPath),
                    to: snapshot,
                    oldSchema: try atBase(CatalogSchema.self, source.schemaPath),
                    newSchema: try CatalogJSON.read(CatalogSchema.self, at: source.schemaPath, in: packageDirectory)
                )
            )
        }
        return changes
    }

    /// Updates the sources' snapshots and schemas, and reports how each source's API changed shape.
    ///
    /// The new snapshots are rendered in memory first, so nothing is written unless every file can be made and the
    /// models can become code.
    private static func fetch(
        _ sources: [CatalogSource],
        into packageDirectory: URL,
        session: URLSession,
        baseURL: URL?,
        today: CatalogDay,
        log: (String) -> Void
    ) async throws(GeneratorError) {
        var fetches: [Fetch] = []
        for source in sources {
            fetches.append(try await fetch(source, into: packageDirectory, session: session, baseURL: baseURL, today: today))
        }
        let snapshots = try merged(fetches, in: packageDirectory)
        _ = try asBrokenSource { () throws(GeneratorError) in try CatalogRenderer.files(for: snapshots) }
        for file in try catalogFiles(of: fetches) {
            _ = try write(file, in: packageDirectory)
        }
        report(fetches, log: log)
    }

    /// Downloads one source's documents and updates its snapshot, without writing anything.
    private static func fetch(
        _ source: CatalogSource,
        into packageDirectory: URL,
        session: URLSession,
        baseURL: URL?,
        today: CatalogDay
    ) async throws(GeneratorError) -> Fetch {
        let documents = try await source.documents(using: session, baseURL: baseURL)
        let catalog = try source.catalog(from: documents)
        let previous = try CatalogJSON.read(CatalogSnapshot.self, at: source.snapshotPath, in: packageDirectory)
        let snapshot = try asBrokenSource { () throws(GeneratorError) in
            try CatalogSnapshot.updated(source: source, fetched: catalog, previous: previous, today: today)
        }
        return Fetch(
            snapshot: snapshot,
            schema: try source.schema(of: documents),
            previousSchema: try CatalogJSON.read(CatalogSchema.self, at: source.schemaPath, in: packageDirectory)
        )
    }

    /// Every source's snapshot: the fetched one where there is one, and otherwise the one in the package, if any.
    private static func merged(_ fetches: [Fetch], in packageDirectory: URL) throws(GeneratorError) -> [CatalogSnapshot] {
        var snapshots: [CatalogSnapshot] = []
        for source in CatalogSource.allCases {
            if let fetch = fetches.first(where: { $0.snapshot.source == source }) {
                snapshots.append(fetch.snapshot)
            } else if let snapshot = try CatalogJSON.read(CatalogSnapshot.self, at: source.snapshotPath, in: packageDirectory) {
                snapshots.append(snapshot)
            }
        }
        return snapshots
    }

    /// The snapshot and schema files of the fetched sources.
    private static func catalogFiles(of fetches: [Fetch]) throws(GeneratorError) -> [GeneratedFile] {
        var files: [GeneratedFile] = []
        for fetch in fetches {
            let source = fetch.snapshot.source
            files.append(GeneratedFile(path: source.snapshotPath, contents: try CatalogJSON.encoded(fetch.snapshot)))
            files.append(GeneratedFile(path: source.schemaPath, contents: try CatalogJSON.encoded(fetch.schema)))
        }
        return files
    }

    /// Logs how many models each source has, and how its API changed shape since the previous fetch.
    private static func report(_ fetches: [Fetch], log: (String) -> Void) {
        for fetch in fetches {
            let source = fetch.snapshot.source
            log("Fetched \(fetch.snapshot.models.count) \(source.displayName) models into \(source.snapshotPath).")
            let changes = fetch.previousSchema.map(fetch.schema.changes(since:)) ?? []
            if !changes.isEmpty {
                log("\(source.displayName)'s API changed shape:")
                for change in changes { log("  \(change)") }
            }
        }
    }

    /// Runs a step on fetched data, so data that can't become code fails the fetch as a broken source.
    private static func asBrokenSource<Value>(_ step: () throws(GeneratorError) -> Value) throws(GeneratorError) -> Value {
        do {
            return try step()
        } catch .invalidCatalog(let message) {
            throw .brokenSource("The fetched models can't become code: \(message)")
        }
    }

    /// The generated files for every source's snapshot.
    ///
    /// - Throws: ``GeneratorError/fileAccess(_:)`` when a source has no snapshot yet.
    private static func generatedFiles(in packageDirectory: URL) throws(GeneratorError) -> [GeneratedFile] {
        let snapshots = try CatalogSource.allCases.map { (source) throws(GeneratorError) in
            guard let snapshot = try CatalogJSON.read(CatalogSnapshot.self, at: source.snapshotPath, in: packageDirectory) else {
                throw .fileAccess("\(source.snapshotPath) is missing. Run `fetch` to create it.")
            }
            return snapshot
        }
        return try CatalogRenderer.files(for: snapshots)
    }

    /// Writes a file unless it already holds the contents, so an unchanged file keeps its modification date.
    ///
    /// - Returns: Whether the file changed.
    private static func write(_ file: GeneratedFile, in packageDirectory: URL) throws(GeneratorError) -> Bool {
        let url = packageDirectory.appending(path: file.path)
        let data = Data(file.contents.utf8)
        guard (try? Data(contentsOf: url)) != data else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw .fileAccess("Couldn't write \(file.path): \(error.localizedDescription)")
        }
        return true
    }
}
