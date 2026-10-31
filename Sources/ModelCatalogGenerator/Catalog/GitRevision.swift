import Foundation

/// The package's files as a git commit has them.
struct GitRevision {
    let ref: String
    let packageDirectory: URL

    /// A revision of the package's repository.
    ///
    /// - Throws: ``GeneratorError/usage(_:)`` when `ref` names no commit, and ``GeneratorError/fileAccess(_:)`` when git
    ///   can't run.
    init(_ ref: String, in packageDirectory: URL) throws(GeneratorError) {
        self.ref = ref
        self.packageDirectory = packageDirectory
        guard try git("rev-parse", "--verify", "--quiet", "\(ref)^{commit}").status == 0 else {
            throw .usage("'\(ref)' names no commit of the repository at \(packageDirectory.path(percentEncoded: false)).")
        }
    }

    /// A file's contents at the revision.
    ///
    /// - Parameter path: The file, relative to the package root.
    /// - Returns: The contents, or `nil` when the revision has no such file.
    /// - Throws: ``GeneratorError/fileAccess(_:)`` when git can't run or can't read the file.
    func contents(of path: String) throws(GeneratorError) -> Data? {
        guard try git("cat-file", "-e", "\(ref):./\(path)").status == 0 else { return nil }
        let show = try git("show", "\(ref):./\(path)")
        guard show.status == 0 else { throw .fileAccess("Couldn't read \(path) at \(ref).") }
        return show.output
    }

    /// Runs git in the package directory and returns its exit status and standard output.
    private func git(_ arguments: String...) throws(GeneratorError) -> (status: Int32, output: Data) {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = ["git", "-C", packageDirectory.path(percentEncoded: false)] + arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw .fileAccess("Couldn't run git: \(error.localizedDescription)")
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, data)
    }
}
