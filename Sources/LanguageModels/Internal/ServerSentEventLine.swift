/// One line of a server-sent event stream.
///
/// A stream is read line by line, as ``ByteLines`` gives it. A blank line ends an event, so a reader that gathers
/// `event:` and `data:` lines knows when to handle them. A comment line, which servers send to keep a connection open,
/// carries nothing.
package enum ServerSentEventLine: Equatable, Sendable {
    /// A `data:` line's payload.
    case data(String)

    /// An `event:` line's name.
    case event(String)

    /// The blank line that ends an event.
    case endOfEvent

    /// A comment, or a field the reader doesn't use, such as `id:` or `retry:`.
    case ignored

    /// Reads one line.
    ///
    /// - Parameter line: The line, without its line break.
    package init(_ line: some StringProtocol) {
        guard !line.isEmpty else {
            self = .endOfEvent
            return
        }
        guard let colon = line.firstIndex(of: ":"), colon != line.startIndex else {
            self = .ignored
            return
        }
        var value = line[line.index(after: colon)...]
        if value.first == " " { value = value.dropFirst() }
        switch String(line[..<colon]) {
        case "data": self = .data(String(value))
        case "event": self = .event(String(value))
        default: self = .ignored
        }
    }
}
