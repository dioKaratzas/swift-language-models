public import Foundation

extension OpenRouterPricing {
    /// Prices that replace the base prices while a condition holds. A price it doesn't set stays as it was.
    public struct Override: Sendable, Hashable {
        /// When the override applies.
        public let condition: Condition

        /// The price of one prompt token.
        public let prompt: Decimal?

        /// The price of one generated token.
        public let completion: Decimal?

        /// The price of one prompt token read from the prompt cache.
        public let cacheRead: Decimal?

        /// The price of one prompt token written to the prompt cache.
        public let cacheWrite: Decimal?

        /// Creates an override.
        ///
        /// - Parameters:
        ///   - condition: When the override applies.
        ///   - prompt: The price of one prompt token.
        ///   - completion: The price of one generated token.
        ///   - cacheRead: The price of one prompt token read from the prompt cache.
        ///   - cacheWrite: The price of one prompt token written to the prompt cache.
        public init(
            condition: Condition,
            prompt: Decimal? = nil,
            completion: Decimal? = nil,
            cacheRead: Decimal? = nil,
            cacheWrite: Decimal? = nil
        ) {
            self.condition = condition
            self.prompt = prompt
            self.completion = completion
            self.cacheRead = cacheRead
            self.cacheWrite = cacheWrite
        }
    }

    /// When an override applies: every part the condition sets must hold, and a condition that sets none always holds.
    public struct Condition: Sendable, Hashable {
        /// The prompt length, in tokens, that a request must exceed.
        public let promptTokensAbove: Int?

        /// The days, in UTC, that a request must be sent on.
        public let weekdays: Set<Locale.Weekday>?

        /// The time of day, in UTC, that a request must be sent in.
        public let hours: TimeWindow?

        /// Creates a condition.
        ///
        /// - Parameters:
        ///   - promptTokensAbove: The prompt length, in tokens, that a request must exceed.
        ///   - weekdays: The days, in UTC, that a request must be sent on.
        ///   - hours: The time of day, in UTC, that a request must be sent in.
        public init(promptTokensAbove: Int? = nil, weekdays: Set<Locale.Weekday>? = nil, hours: TimeWindow? = nil) {
            self.promptTokensAbove = promptTokensAbove
            self.weekdays = weekdays
            self.hours = hours
        }

        /// Whether the condition holds for a request.
        func holds(promptTokens: Int, at moment: Moment) -> Bool {
            promptTokensAbove.map { promptTokens > $0 } != false
                && weekdays?.contains(moment.weekday) != false
                && hours?.contains(moment.timeOfDay) != false
        }
    }

    /// A daily window of time in UTC, which runs past midnight when it ends before it starts.
    public struct TimeWindow: Sendable, Hashable {
        /// When the window opens, as the time after midnight.
        public let start: Duration

        /// When the window closes, as the time after midnight. A time that equals it is outside the window.
        public let end: Duration

        /// Creates a window.
        ///
        /// - Parameters:
        ///   - start: When the window opens, as the time after midnight UTC.
        ///   - end: When the window closes, as the time after midnight UTC.
        public init(start: Duration, end: Duration) {
            self.start = start
            self.end = end
        }

        /// Whether a time of day falls in the window.
        ///
        /// - Parameter timeOfDay: The time after midnight UTC.
        /// - Returns: Whether the time is from ``start`` up to, but not including, ``end``.
        public func contains(_ timeOfDay: Duration) -> Bool {
            start <= end ? (start..<end).contains(timeOfDay) : timeOfDay >= start || timeOfDay < end
        }
    }

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
