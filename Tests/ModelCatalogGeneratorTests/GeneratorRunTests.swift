import Foundation
import LanguageModelsTestSupport
import Testing

@testable import ModelCatalogGenerator

@Suite("Generator run")
final class GeneratorRunTests {
    private let package = FileManager.default.temporaryDirectory.appending(
        path: "ModelCatalogGeneratorTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )

    deinit {
        try? FileManager.default.removeItem(at: package)
    }

    @Test func `fetch, render and check run end to end`() async throws {
        let stub = try fixtureStub()

        try await run(.fetch, stub: stub)
        try await run(.render, stub: stub)
        try await run(.check, stub: stub)

        #expect(
            stub.requests.map { $0.request.url?.absoluteString } == [
                "\(stub.baseURL.absoluteString)/models?output_modalities=text",
                "\(stub.baseURL.absoluteString)/openapi.json",
            ])
        for (path, goldenName) in [
            ("Catalogs/openrouter.json", "openrouter.json.golden"), ("Catalogs/openrouter.schema.json", "openrouter.schema.json.golden"),
        ] {
            let written = try String(contentsOf: package.appending(path: path), encoding: .utf8)
            #expect(try golden(goldenName) == written, "\(path)")
        }
    }

    @Test func `render leaves files that are already up to date alone`() async throws {
        let stub = try fixtureStub()
        try await run(.fetch, stub: stub)
        let firstRender = try await run(.render, stub: stub)

        let secondRender = try await run(.render, stub: stub)

        #expect(firstRender.contains("Rendered \(EffortSetsTemplate.path)."))
        #expect(secondRender == ["Generated files are up to date."])
    }

    @Test func `check fails when a generated file was edited`() async throws {
        let stub = try fixtureStub()
        try await run(.fetch, stub: stub)
        try await run(.render, stub: stub)
        try Data("// edited\n".utf8).write(to: package.appending(path: EffortSetsTemplate.path))

        await #expect(throws: GeneratorError.stale([EffortSetsTemplate.path])) {
            try await self.run(.check, stub: stub)
        }
    }

    @Test(arguments: [Command.Action.render, .check])
    func `render and check fail without a snapshot`(action: Command.Action) async {
        await #expect(throws: GeneratorError.fileAccess("Catalogs/openrouter.json is missing. Run `fetch` to create it.")) {
            try await self.run(action, stub: HTTPStub())
        }
    }

    @Test func `a snapshot that doesn't decode fails with its path`() async throws {
        try FileManager.default.createDirectory(at: package.appending(path: "Catalogs"), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: package.appending(path: "Catalogs/openrouter.json"))

        let error = await #expect(throws: GeneratorError.self) {
            try await self.run(.render, stub: HTTPStub())
        }

        #expect(error?.exitCode == 65)
        #expect(error?.description.hasPrefix("Catalogs/openrouter.json doesn't decode:") == true)
    }

    @Test func `an HTTP error from the source fails the fetch and writes nothing`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":500,"message":"down"}}"#, status: 500))

        await #expect(throws: GeneratorError.brokenSource("OpenRouter returned HTTP 500 instead of a model list.")) {
            try await self.run(.fetch, stub: stub)
        }
        #expect(!FileManager.default.fileExists(atPath: package.appending(path: "Catalogs").path(percentEncoded: false)))
    }

    @Test func `models that can't become code fail the fetch and write nothing`() async throws {
        let documents = try fixtureDocuments()
        let modelList = String(decoding: documents.modelList, as: UTF8.self)
            .replacing(#""completion": "0.000015""#, with: #""completion": "free""#)
        let stub = HTTPStub(.json(modelList), .json(String(decoding: documents.apiDescription, as: UTF8.self)))
        let problem = "OpenRouter model anthropic/claude-sonnet-4.6 has an invalid completion price: 'free'."

        let error = await #expect(throws: GeneratorError.brokenSource("The fetched models can't become code: \(problem)")) {
            try await self.run(.fetch, stub: stub)
        }

        #expect(error?.exitCode == 2)
        #expect(!FileManager.default.fileExists(atPath: package.appending(path: "Catalogs").path(percentEncoded: false)))
    }

    @Test func `a network failure is tried once more`() async throws {
        let stub = HTTPStub(.json(String(decoding: try fixtureDocuments().modelList, as: UTF8.self)))

        let error = await #expect(throws: GeneratorError.self) {
            try await CatalogSource.openrouter.documents(using: stub.session, baseURL: stub.baseURL, retryDelay: .zero)
        }

        #expect(error?.exitCode == 2)
        #expect(error?.description.hasPrefix("OpenRouter couldn't be reached:") == true)

        #expect(stub.requests.compactMap { $0.request.url?.lastPathComponent } == ["models", "openapi.json", "openapi.json"])
    }

    private func fixtureStub() throws -> HTTPStub {
        let documents = try fixtureDocuments()
        return HTTPStub(
            .json(String(decoding: documents.modelList, as: UTF8.self)),
            .json(String(decoding: documents.apiDescription, as: UTF8.self))
        )
    }

    /// Runs a subcommand against the stub and returns what it logged.
    @discardableResult
    private func run(_ action: Command.Action, stub: HTTPStub) async throws -> [String] {
        let command = Command(action: action, packageDirectory: package, sources: [.openrouter])
        var log: [String] = []
        try await Generator.run(command, session: stub.session, baseURL: stub.baseURL, today: "2026-10-29") { log.append($0) }
        return log
    }
}
