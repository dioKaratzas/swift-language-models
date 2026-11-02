extension OpenRouterPricing {
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
}
