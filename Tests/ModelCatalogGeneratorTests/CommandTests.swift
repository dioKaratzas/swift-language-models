import Foundation
import Testing

@testable import ModelCatalogGenerator

@Suite("Command line")
struct CommandTests {
    private static let currentDirectory = URL(filePath: "/work/package", directoryHint: .isDirectory)

    @Test func `a subcommand with options parses`() throws {
        let command = try Command.parse(
            ["fetch", "--sources", "openrouter", "--package-directory", "../other"],
            currentDirectory: Self.currentDirectory
        )

        #expect(command?.action == .fetch)
        #expect(command?.sources == [.openrouter])
        #expect(command?.packageDirectory.path(percentEncoded: false) == "/work/other/")
    }

    @Test func `help gives no command`() throws {
        #expect(try Command.parse(["render", "--help"], currentDirectory: Self.currentDirectory) == nil)
    }

    @Test(arguments: [[], ["build"], ["fetch", "--sources"], ["fetch", "--sources", "nowhere"], ["check", "--verbose", "yes"]])
    func `arguments the generator doesn't accept fail with a usage error`(arguments: [String]) {
        let error = #expect(throws: GeneratorError.self) {
            try Command.parse(arguments, currentDirectory: Self.currentDirectory)
        }
        #expect(error?.exitCode == 64)
    }

    @Test(arguments: [
        (GeneratorError.usage("x"), Int32(64)),
        (.brokenSource("x"), 2),
        (.stale(["x"]), 1),
        (.invalidCatalog("x"), 65),
        (.fileAccess("x"), 74),
    ])
    func `each failure exits with its own code`(error: GeneratorError, exitCode: Int32) {
        #expect(error.exitCode == exitCode)
    }
}
