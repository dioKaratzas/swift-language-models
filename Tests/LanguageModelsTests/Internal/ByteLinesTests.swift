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

@Suite("Same-host redirects")
struct SameHostRedirectsTests {
    @Test(arguments: [
        ("https://api.example.com/v1/chat", "https://api.example.com/v2/chat", true),
        ("https://api.example.com/v1/chat", "https://evil.example.org/v1/chat", false),
        ("https://api.example.com/v1/chat", "http://api.example.com/v1/chat", false),
        ("https://api.example.com/v1/chat", "https://api.example.com:8443/v1/chat", false),
    ])
    func `a redirect is followed only to the same scheme, host and port`(from: String, to: String, isFollowed: Bool) async throws {
        let original = try #require(URL(string: from))
        let target = try #require(URL(string: to))
        let task = URLSession.shared.dataTask(with: original)
        let response = try #require(HTTPURLResponse(url: original, statusCode: 307, httpVersion: nil, headerFields: nil))

        let followed = await SameHostRedirects().urlSession(
            .shared,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: target)
        )

        #expect((followed != nil) == isFollowed)
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
