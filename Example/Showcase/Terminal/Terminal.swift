import Foundation

/// Reads from and writes to the terminal.
enum Terminal {
    /// Whether standard output is a terminal that takes escape codes, rather than a pipe or a file. A terminal whose
    /// `TERM` is unset or `dumb` counts as one that doesn't.
    static let isInteractive = isatty(STDOUT_FILENO) == 1 && ProcessInfo.processInfo.environment["TERM", default: "dumb"] != "dumb"

    /// Prints a prompt and reads the line typed after it, or returns `nil` at the end of the input.
    static func ask(_ prompt: String) -> String? {
        print(Style.bold(prompt), terminator: "")
        fflush(stdout)
        return readLine()
    }

    /// Prints a message to standard error.
    static func printError(_ message: String) {
        FileHandle.standardError.write(Data((Style.red(message) + "\n").utf8))
    }

    /// The number of rows a text takes, with its long lines wrapped at the terminal's width.
    static func rows(in text: String) -> Int {
        var size = winsize()
        let width = ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 && size.ws_col > 0 ? Int(size.ws_col) : 80
        return text.split(separator: "\n", omittingEmptySubsequences: false).reduce(0) { rows, line in
            rows + max(1, (line.count + width - 1) / width)
        }
    }
}
