import Foundation

/// Swift source text for literal values.
enum SwiftLiteral {
    /// A string literal, with quotes, backslashes and line breaks escaped.
    static func string(_ value: String) -> String {
        var escaped = ""
        for character in value {
            switch character {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default: escaped.append(character)
            }
        }
        return "\"\(escaped)\""
    }

    /// An integer literal with its digits grouped in threes, such as `200_000`.
    static func integer(_ value: Int) -> String {
        let digits = String(value.magnitude)
        var grouped = ""
        for (offset, digit) in digits.enumerated() {
            if offset > 0, (digits.count - offset) % 3 == 0 { grouped += "_" }
            grouped.append(digit)
        }
        return value < 0 ? "-" + grouped : grouped
    }

    /// An exact `Decimal` expression for decimal text such as `0.0000025`, or `nil` when the text isn't a plain
    /// non-negative decimal.
    static func decimal(_ text: String) -> String? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
            !parts[0].isEmpty
        else { return nil }
        let fraction = parts.count == 2 ? parts[1] : ""
        let digits = (parts[0] + fraction).drop { $0 == "0" }
        guard let significand = Int(digits.isEmpty ? "0" : String(digits)) else { return nil }
        return "Decimal(sign: .plus, exponent: \(-fraction.count), significand: \(integer(significand)))"
    }

    /// A `Duration` expression for the time after midnight on an `HHMM` clock number, such as `.seconds(5_400)` for
    /// `130`, or `nil` when the number isn't a time from 00:00 to 24:00.
    static func duration(clockTime: Int) -> String? {
        let (hours, minutes) = clockTime.quotientAndRemainder(dividingBy: 100)
        guard (0...24).contains(hours), (0..<60).contains(minutes), hours < 24 || minutes == 0 else { return nil }
        return ".seconds(\(integer(hours * 3_600 + minutes * 60)))"
    }

    /// A `Date` expression for a number of seconds since 1970.
    static func date(secondsSince1970 seconds: Int) -> String {
        "Date(timeIntervalSince1970: \(integer(seconds)))"
    }

    /// A `Date` expression for midnight UTC on a day such as `2026-12-31`, or `nil` when the text isn't such a day.
    static func date(day: String) -> String? {
        guard let date = try? Date.ISO8601FormatStyle().year().month().day().parse(day) else { return nil }
        return Self.date(secondsSince1970: Int(date.timeIntervalSince1970))
    }
}
