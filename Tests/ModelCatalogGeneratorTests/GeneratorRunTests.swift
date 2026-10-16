import Foundation
import LanguageModelsTesting
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

        #expect(stub.requests.first?.request.url?.path() == "/models")
        let snapshot = try String(contentsOf: package.appending(path: "Catalogs/openrouter.json"), encoding: .utf8)
        #expect(try golden("openrouter.json.golden") == snapshot)
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

    @Test func `an HTTP error from the source fails the fetch and writes nothing`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":500,"message":"down"}}"#, status: 500))

        await #expect(throws: GeneratorError.brokenSource("OpenRouter returned HTTP 500.")) {
            try await self.run(.fetch, stub: stub)
        }
        #expect(!FileManager.default.fileExists(atPath: package.appending(path: "Catalogs").path(percentEncoded: false)))
    }

    private func fixtureStub() throws -> HTTPStub {
        HTTPStub(.json(String(decoding: try Bundle.module.fixture("openrouter-models.json"), as: UTF8.self)))
    }

    private func run(_ action: Command.Action, stub: HTTPStub) async throws {
        let command = Command(action: action, packageDirectory: package, sources: [.openrouter])
        try await Generator.run(command, session: stub.session, baseURL: stub.baseURL, today: "2026-10-29")
    }
}
