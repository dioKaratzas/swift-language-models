import Foundation

/// What the generator was asked to do.
struct Command: Equatable {
    /// The generator's subcommands.
    enum Action: String {
        case fetch
        case render
        case check
    }

    static let usage = """
        USAGE: ModelCatalogGenerator <fetch | render | check> [options]

        SUBCOMMANDS:
          fetch    Download the providers' model lists into Catalogs/.
          render   Turn the catalogs into Swift sources.
          check    Exit with code 1 when the Swift sources don't match the catalogs.

        OPTIONS:
          --package-directory <path>   The package root (default: the current directory).
          --sources <names>            Comma-separated sources to fetch (default: all). Sources: \
        \(CatalogSource.allCases.map(\.rawValue).joined(separator: ", ")).
          -h, --help                   Show this help.
        """

    let action: Action
    let packageDirectory: URL
    let sources: [CatalogSource]

    /// Parses the arguments after the executable name.
    ///
    /// - Parameters:
    ///   - arguments: The command-line arguments, without the executable name.
    ///   - currentDirectory: The directory used when `--package-directory` is missing.
    /// - Returns: The command, or `nil` when help was requested.
    /// - Throws: ``GeneratorError/usage(_:)`` for arguments the generator doesn't accept.
    static func parse(_ arguments: [String], currentDirectory: URL) throws(GeneratorError) -> Command? {
        guard !arguments.contains(where: { $0 == "--help" || $0 == "-h" }) else { return nil }
        guard let first = arguments.first else { throw .usage("Missing subcommand.") }
        guard let action = Action(rawValue: first) else { throw .usage("Unknown subcommand '\(first)'.") }

        var packageDirectory = currentDirectory
        var sources = CatalogSource.allCases
        var remaining = arguments.dropFirst()
        while let option = remaining.popFirst() {
            guard let value = remaining.popFirst() else { throw .usage("Missing value for '\(option)'.") }
            switch option {
            case "--package-directory":
                packageDirectory = URL(filePath: value, directoryHint: .isDirectory, relativeTo: currentDirectory)
            case "--sources":
                sources = try value.split(separator: ",").map { name throws(GeneratorError) in
                    guard let source = CatalogSource(rawValue: String(name)) else {
                        throw .usage("Unknown source '\(name)'.")
                    }
                    return source
                }
            default:
                throw .usage("Unknown option '\(option)'.")
            }
        }
        return Command(action: action, packageDirectory: packageDirectory.standardizedFileURL, sources: sources)
    }
}
