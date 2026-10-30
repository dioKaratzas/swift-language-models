import Foundation

/// Swift source text for literal values.
enum SwiftLiteral {
    /// A string literal, with quotes and backslashes escaped, and every character that doesn't print, such as a line
    /// break, written as an escape.
    static func string(_ value: String) -> String {
        var escaped = ""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            case _ where !scalar.isPrintable: escaped += "\\u{\(String(scalar.value, radix: 16, uppercase: true))}"
            default: escaped.unicodeScalars.append(scalar)
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

    /// A `Date` expression for a number of seconds since 1970.
    static func date(secondsSince1970 seconds: Int) -> String {
        "Date(timeIntervalSince1970: \(integer(seconds)))"
    }

    /// A `Date` expression for midnight UTC at the start of a day.
    static func date(_ day: CatalogDay) -> String {
        date(secondsSince1970: Int(day.start.timeIntervalSince1970))
    }
}
