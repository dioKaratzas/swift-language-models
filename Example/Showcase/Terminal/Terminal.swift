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

    /// Splits a typed line into words as a shell does: quotes keep spaces in a word, and a backslash keeps the next
    /// character, as in a path dragged into the terminal, such as `~/My\ Files/lease.pdf`.
    static func words(in line: String) -> [String] {
        var words: [String] = []
        var word = ""
        var isInWord = false
        var quote: Character?
        var isEscaped = false
        for character in line {
            if isEscaped {
                word.append(character)
                isEscaped = false
            } else if let open = quote {
                if character == open { quote = nil } else { word.append(character) }
            } else if character == "\\" {
                isEscaped = true
                isInWord = true
            } else if character == "'" || character == "\"" {
                quote = character
                isInWord = true
            } else if character.isWhitespace {
                if isInWord { words.append(word) }
                word = ""
                isInWord = false
            } else {
                word.append(character)
                isInWord = true
            }
        }
        if isInWord { words.append(word) }
        return words
    }

    /// Prints a prompt and reads the line typed after it from the terminal without showing it, or returns `nil` when
    /// there's no terminal to read from.
    ///
    /// The buffer that held the typing is zeroed before the function returns.
    static func askHidden(_ prompt: String) -> String? {
        withUnsafeTemporaryAllocation(of: CChar.self, capacity: 1024) { buffer in
            defer { buffer.update(repeating: 0) }
            guard let start = buffer.baseAddress,
                let line = readpassphrase(Style.bold(prompt), start, buffer.count, RPP_REQUIRE_TTY)
            else { return nil }
            return String(cString: line)
        }
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
