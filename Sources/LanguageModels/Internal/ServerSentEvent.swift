/// One line of a server-sent event stream.
///
/// A stream is read line by line, as `URLSession.AsyncBytes.lines` gives it. A comment line, which servers send to
/// keep a connection open, carries nothing.
package enum ServerSentEvent: Equatable, Sendable {
    /// A `data:` line's payload.
    case data(String)

    /// An `event:` line's name.
    case event(String)

    /// A comment, a blank line, or a field the reader doesn't use, such as `id:` or `retry:`.
    case ignored

    /// Reads one line.
    ///
    /// - Parameter line: The line, without its line break.
    package init(line: Substring) {
        guard let colon = line.firstIndex(of: ":"), colon != line.startIndex else {
            self = .ignored
            return
        }
        var value = line[line.index(after: colon)...]
        if value.first == " " { value = value.dropFirst() }
        switch line[..<colon] {
        case "data": self = .data(String(value))
        case "event": self = .event(String(value))
        default: self = .ignored
        }
    }
}
