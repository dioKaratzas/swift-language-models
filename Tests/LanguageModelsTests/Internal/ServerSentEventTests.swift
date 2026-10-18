import LanguageModels
import Testing

@Suite("Server-sent events")
struct ServerSentEventTests {
    @Test(arguments: [
        ("data: {\"a\":1}", ServerSentEvent.data("{\"a\":1}")),
        ("data:{\"a\":1}", .data("{\"a\":1}")),
        ("data:  two spaces", .data(" two spaces")),
        ("data: [DONE]", .data("[DONE]")),
        ("event: message_start", .event("message_start")),
        (": OPENROUTER PROCESSING", .ignored),
        ("", .ignored),
        ("id: 7", .ignored),
        ("data", .ignored),
    ])
    func `a line becomes its event`(line: String, event: ServerSentEvent) {
        #expect(ServerSentEvent(line: line[...]) == event)
    }
}
