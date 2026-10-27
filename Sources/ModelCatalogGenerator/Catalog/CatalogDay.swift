import Foundation

/// A day in UTC, such as a model's knowledge cutoff or the day a word was removed, which catalogs write as
/// `yyyy-MM-dd`.
struct CatalogDay: Hashable, Sendable, CustomStringConvertible {
    private static let format = Date.ISO8601FormatStyle().year().month().day()

    /// The day as `yyyy-MM-dd`.
    let description: String

    /// Midnight UTC at the start of the day.
    let start: Date

    /// The day a text names, or `nil` unless the text is a real day written as `yyyy-MM-dd`.
    ///
    /// The ISO 8601 parser alone also takes text such as `2026-02-30`, which it rolls over into March, or `2026-2-3`,
    /// and ignores whatever follows the day, so the text must also be how the parsed day is written.
    init?(_ text: String) {
        guard let start = try? Self.format.parse(text), start.formatted(Self.format) == text else { return nil }
        self.description = text
        self.start = start
    }

    /// The day in UTC that a moment falls on.
    init(containing date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        start = calendar.startOfDay(for: date)
        description = start.formatted(Self.format)
    }
}

extension CatalogDay: Codable {
    /// Decodes a day from its text.
    ///
    /// - Throws: `DecodingError.dataCorrupted` when the text isn't a real day written as `yyyy-MM-dd`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let day = CatalogDay(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "'\(text)' isn't a day written as yyyy-MM-dd.")
        }
        self = day
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
