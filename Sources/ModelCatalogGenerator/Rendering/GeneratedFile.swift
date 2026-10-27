/// A file the generator writes, such as a Swift source or a catalog, at a path relative to the package root.
struct GeneratedFile: Equatable, Sendable {
    let path: String
    let contents: String
}
