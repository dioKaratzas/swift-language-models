/// One answer's stream as a format reads it, one server-sent event at a time.
package protocol StreamedAnswer {
    /// Sends the events for one server-sent event.
    ///
    /// - Returns: Whether the event ends the stream.
    mutating func receive(_ event: ServerSentEvent) async throws -> Bool

    /// Whether any of the answer's output has arrived: text, reasoning or a tool call.
    var hasOutput: Bool { get }
}
