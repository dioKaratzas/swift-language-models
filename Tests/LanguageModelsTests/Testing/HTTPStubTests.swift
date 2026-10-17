import Foundation
import LanguageModelsTesting
import Testing

@Suite("HTTP stub")
struct HTTPStubTests {
    @Test func `a fixture streams in small chunks that reassemble into lines`() async throws {
        let stub = HTTPStub(.eventStream(try Bundle.module.fixture("two-events.sse"), chunkSize: 3))

        let (bytes, response) = try await stub.session.bytes(from: stub.baseURL.appending(path: "stream"))
        var lines: [String] = []
        for try await line in bytes.lines {
            lines.append(line)
        }

        #expect((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") == "text/event-stream")
        #expect(lines == [": keep-alive", #"data: {"text":"first"}"#, #"data: {"text":"second"}"#, "data: [DONE]"])
    }

    @Test func `a stub records each request with its body`() async throws {
        let stub = HTTPStub(.json(#"{"ok":true}"#))
        var request = URLRequest(url: stub.baseURL.appending(path: "v1/chat"))
        request.httpMethod = "POST"
        request.setValue("Bearer test", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(#"{"model":"x","stream":true}"#.utf8)

        _ = try await stub.session.data(for: request)

        let recorded = try #require(stub.requests.first)
        #expect(recorded.request.httpMethod == "POST")
        #expect(recorded.request.url?.path() == "/v1/chat")
        #expect(recorded.request.value(forHTTPHeaderField: "Authorization") == "Bearer test")
        #expect(try canonicalJSON(recorded.body) == canonicalJSON(#"{"stream":true,"model":"x"}"#))
    }

    @Test func `a stub serves its responses in order, then fails`() async throws {
        let stub = HTTPStub(.json("{}", status: 503), .json("{}"))

        let first = try await stub.session.data(from: stub.baseURL).1 as? HTTPURLResponse
        let second = try await stub.session.data(from: stub.baseURL).1 as? HTTPURLResponse

        #expect(first?.statusCode == 503)
        #expect(second?.statusCode == 200)
        let error = await #expect(throws: URLError.self) {
            try await stub.session.data(from: stub.baseURL)
        }
        #expect(error?.code == .resourceUnavailable)
        #expect(stub.requests.count == 3)
    }

    @Test func `stubs running at once keep their own responses`() async throws {
        let first = HTTPStub(.json(#""first""#))
        let second = HTTPStub(.json(#""second""#))

        async let firstBody = first.session.data(from: first.baseURL).0
        async let secondBody = second.session.data(from: second.baseURL).0

        #expect(String(decoding: try await firstBody, as: UTF8.self) == #""first""#)
        #expect(String(decoding: try await secondBody, as: UTF8.self) == #""second""#)
    }

    @Test func `a missing fixture throws`() {
        #expect(throws: CocoaError.self) {
            try Bundle.module.fixture("missing.sse")
        }
    }
}
