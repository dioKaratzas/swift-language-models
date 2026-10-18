/// A failure that ends a generator run.
enum GeneratorError: Error, Equatable, CustomStringConvertible {
    /// The command line couldn't be parsed.
    case usage(String)

    /// A source failed or returned data that looks broken, so nothing was written.
    case brokenSource(String)

    /// The generated files differ from the ones in the package.
    case stale([String])

    /// The catalogs can't become code, for example because two models get the same Swift name, or a catalog file
    /// doesn't decode.
    case invalidCatalog(String)

    /// A file in the package is missing, or couldn't be read or written.
    case fileAccess(String)

    /// The process exit code for the failure.
    var exitCode: Int32 {
        switch self {
        case .usage: 64
        case .brokenSource: 2
        case .stale: 1
        case .invalidCatalog: 65
        case .fileAccess: 74
        }
    }

    var description: String {
        switch self {
        case .usage(let message): "\(message)\n\n\(Command.usage)"
        case .stale(let paths): "Generated files are out of date: \(paths.joined(separator: ", ")). Run `render`."
        case .brokenSource(let message), .invalidCatalog(let message), .fileAccess(let message): message
        }
    }
}
