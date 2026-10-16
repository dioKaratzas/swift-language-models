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
        #expect {
            try Command.parse(arguments, currentDirectory: Self.currentDirectory)
        } throws: { error in
            (error as? GeneratorError)?.exitCode == 64
        }
    }
}
