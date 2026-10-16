import Foundation
import PackagePlugin

/// Downloads the providers' model lists and regenerates the typed model data, by running `ModelCatalogGenerator`'s
/// `fetch` and then `render`.
@main
struct GenerateModelCatalog: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "ModelCatalogGenerator")
        guard !arguments.contains("--help"), !arguments.contains("-h") else {
            try run(tool, ["--help"])
            return
        }
        let packageDirectory = ["--package-directory", context.package.directoryURL.path(percentEncoded: false)]
        try run(tool, ["fetch"] + packageDirectory + arguments)
        try run(tool, ["render"] + packageDirectory)
    }

    private func run(_ tool: PluginContext.Tool, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = tool.url
        process.arguments = arguments
        process.environment = [:]
        try process.run()
        process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw GeneratorFailure(arguments: arguments, status: process.terminationStatus)
        }
    }
}

/// `ModelCatalogGenerator` exited with an error, which it already printed.
struct GeneratorFailure: Error, CustomStringConvertible {
    let arguments: [String]
    let status: Int32

    var description: String {
        "ModelCatalogGenerator \(arguments.first ?? "") exited with status \(status)."
    }
}
