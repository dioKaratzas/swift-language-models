import Foundation

/// Prints a streamed text as it grows.
///
/// Each snapshot of a stream holds the whole text so far, so only the part that's new since the last one is printed.
struct Streamer {
    private var printed = ""

    mutating func show(_ text: String) {
        // After the model calls a tool, its next round starts the text over.
        let new = text.hasPrefix(printed) ? String(text.dropFirst(printed.count)) : "\n" + text
        print(new, terminator: "")
        fflush(stdout)  // stdout is line-buffered, and the new part is often less than a line
        printed = text
    }

    /// Ends the text's last line.
    mutating func finish() {
        if !printed.isEmpty { print() }
        printed = ""
    }
}

/// Shows a text that changes as it streams, such as a value generated part by part, by redrawing it in place.
///
/// Redrawing needs an interactive terminal, so elsewhere, such as in a pipe, only the last text is printed.
struct LiveText {
    private var latest = ""
    private var rows = 0

    mutating func show(_ text: String) {
        latest = text
        guard Terminal.isInteractive else { return }
        // Moves to the start of the text's first row, and clears from there down.
        if rows > 0 { print("\u{1B}[\(rows)F\u{1B}[J", terminator: "") }
        print(text)
        rows = Terminal.rows(in: text)
    }

    /// Prints the last text where it wasn't redrawn.
    func finish() {
        if !Terminal.isInteractive { print(latest) }
    }
}
