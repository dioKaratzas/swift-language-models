import LanguageModels
import Testing

@Suite("Server-sent events")
struct ServerSentEventTests {
    @Test(arguments: [
        ("data: {\"a\":1}", ServerSentEvent.Line.data("{\"a\":1}")),
        ("data:{\"a\":1}", .data("{\"a\":1}")),
        ("data:  two spaces", .data(" two spaces")),
        ("data: [DONE]", .data("[DONE]")),
        ("event: message_start", .event("message_start")),
        (": OPENROUTER PROCESSING", .ignored),
        ("", .endOfEvent),
        ("id: 7", .ignored),
        ("data", .ignored),
    ])
    func `a line becomes its part of an event`(line: String, part: ServerSentEvent.Line) {
        #expect(ServerSentEvent.Line(line) == part)
    }

    @Test func `events end at blank lines, join their data lines and keep their names`() async throws {
        let stream = ": keep-alive\n\nevent: message_start\ndata: {\"a\":\ndata: 1}\n\ndata: [DONE]"
        var events: [ServerSentEvent] = []

        for try await event in ServerSentEvent.Events(Bytes(Array(stream.utf8))) {
            events.append(event)
        }

        #expect(events == [ServerSentEvent(name: "message_start", data: "{\"a\":\n1}"), ServerSentEvent(data: "[DONE]")])
    }
}

/// Bytes as an async sequence.
private struct Bytes: AsyncSequence {
    typealias Element = UInt8
    let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(bytes: bytes[...])
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        var bytes: ArraySlice<UInt8>

        mutating func next() async -> UInt8? {
            bytes.popFirst()
        }
    }
}
