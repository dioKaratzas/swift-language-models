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

        /// The price of one prompt token written to the prompt cache for an hour.
        public let cacheWriteOneHour: Decimal?

        /// The price of one audio token in the prompt.
        public let audio: Decimal?

        /// Creates an override.
        ///
        /// - Parameters:
        ///   - condition: When the override applies.
        ///   - prompt: The price of one prompt token.
        ///   - completion: The price of one generated token.
        ///   - cacheRead: The price of one prompt token read from the prompt cache.
        ///   - cacheWrite: The price of one prompt token written to the prompt cache.
        ///   - cacheWriteOneHour: The price of one prompt token written to the prompt cache for an hour.
        ///   - audio: The price of one audio token in the prompt.
        public init(
            condition: Condition,
            prompt: Decimal? = nil,
            completion: Decimal? = nil,
            cacheRead: Decimal? = nil,
            cacheWrite: Decimal? = nil,
            cacheWriteOneHour: Decimal? = nil,
            audio: Decimal? = nil
        ) {
            self.condition = condition
            self.prompt = prompt
            self.completion = completion
            self.cacheRead = cacheRead
            self.cacheWrite = cacheWrite
            self.cacheWriteOneHour = cacheWriteOneHour
            self.audio = audio
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
                if let promptTokensAbove, promptTokens <= promptTokensAbove { return false }
                if let weekdays, !weekdays.contains(moment.weekday) { return false }
                if let hours, !hours.contains(moment.timeOfDay) { return false }
                return true
            }
        }
    }
}
