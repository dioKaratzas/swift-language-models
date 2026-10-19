import Foundation

extension OpenRouterPricing {
    /// A request's send time, as the UTC weekday and time of day an override's condition reads.
    struct Moment {
        private static let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

        let weekday: Locale.Weekday
        let timeOfDay: Duration

        init(_ date: Date) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .gmt
            weekday = Self.weekdays[calendar.component(.weekday, from: date) - 1]
            timeOfDay = .seconds(date.timeIntervalSince(calendar.startOfDay(for: date)))
        }
    }
}
