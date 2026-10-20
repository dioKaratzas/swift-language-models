import Foundation
import LanguageModels
import Testing

@Suite("Byte lines")
struct ByteLinesTests {
    @Test func `lines split only at line feeds and lose a carriage return before one`() async throws {
        let bytes = Array("one\r\ntwo\u{2028}still two\n\nlast".utf8)

        var lines: [String] = []
        for try await line in ByteLines(bytes.async) { lines.append(line) }

        #expect(lines == ["one", "two\u{2028}still two", "", "last"])
    }

    @Test func `a stream ending in a line feed has no empty last line`() async throws {
        var lines: [String] = []
        for try await line in ByteLines(Array("a\nb\n".utf8).async) { lines.append(line) }

        #expect(lines == ["a", "b"])
    }
}

extension Array where Element == UInt8 {
    /// The bytes as an async sequence, like a response body.
    fileprivate var async: AsyncStream<UInt8> {
        let (stream, continuation) = AsyncStream.makeStream(of: UInt8.self)
        for byte in self { continuation.yield(byte) }
        continuation.finish()
        return stream
    }
}
