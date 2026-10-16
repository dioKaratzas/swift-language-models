/// A source file the generator writes, relative to the package root.
struct GeneratedFile: Equatable, Sendable {
    let path: String
    let contents: String
}
