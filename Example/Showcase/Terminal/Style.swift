import Foundation

/// Text styles, left out when the output isn't an interactive terminal or `NO_COLOR` is set.
enum Style {
    static let isEnabled = Terminal.isInteractive && ProcessInfo.processInfo.environment["NO_COLOR", default: ""].isEmpty

    static func bold(_ text: String) -> String { styled(text, code: 1) }
    static func dim(_ text: String) -> String { styled(text, code: 2) }
    static func red(_ text: String) -> String { styled(text, code: 31) }
    static func green(_ text: String) -> String { styled(text, code: 32) }
    static func cyan(_ text: String) -> String { styled(text, code: 36) }

    private static func styled(_ text: String, code: Int) -> String {
        isEnabled ? "\u{1B}[\(code)m\(text)\u{1B}[0m" : text
    }
}

extension String {
    /// The string with spaces after it up to a width, or with one space when it's that long already.
    func padded(to width: Int) -> String {
        self + String(repeating: " ", count: Swift.max(1, width - count))
    }
}
