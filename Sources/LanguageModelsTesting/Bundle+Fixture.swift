package import Foundation

extension Bundle {
    /// The contents of a file in the bundle's `Fixtures` folder.
    ///
    /// The test target copies the folder as a resource with `resources: [.copy("Fixtures")]`, so the folder keeps its
    /// name in the bundle.
    ///
    /// - Parameter name: The file name with its extension, such as `plain-text.sse`.
    /// - Returns: The file's contents.
    /// - Throws: `CocoaError.fileNoSuchFile` when the bundle has no such fixture.
    package func fixture(_ name: String) throws -> Data {
        guard let url = url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "Fixtures/\(name)"])
        }
        return try Data(contentsOf: url)
    }
}
