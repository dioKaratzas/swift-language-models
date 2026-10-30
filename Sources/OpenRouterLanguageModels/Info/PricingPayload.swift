import Foundation

/// A `pricing` object in OpenRouter's model and endpoint lists, with each price as decimal text in US dollars.
struct PricingPayload: Decodable, Sendable {
    /// Prices that replace the base prices while their conditions hold.
    struct Override: Decodable, Sendable {
        let minPromptTokens: Double?
        let utcDays: [String]?
        /// The start of a daily window in UTC, as an `HHMM` clock number such as `130` for 01:30.
        let utcStart: Double?
        /// The end of the window, exclusive, in the same form.
        let utcEnd: Double?
        let prompt: String?
        let completion: String?
        let inputCacheRead: String?
        let inputCacheWrite: String?
        let inputCacheWriteOneHour: String?
        let audio: String?

        private enum CodingKeys: String, CodingKey {
            case minPromptTokens = "min_prompt_tokens"
            case utcDays = "utc_days"
            case utcStart = "utc_start"
            case utcEnd = "utc_end"
            case prompt, completion, audio
            case inputCacheRead = "input_cache_read"
            case inputCacheWrite = "input_cache_write"
            case inputCacheWriteOneHour = "input_cache_write_1h"
        }
    }

    let prompt: String?
    let completion: String?
    let inputCacheRead: String?
    let inputCacheWrite: String?
    let inputCacheWriteOneHour: String?
    let internalReasoning: String?
    let audio: String?
    let image: String?
    let request: String?
    let webSearch: String?
    /// The fraction taken off the endpoint's prices, from 0 to 1.
    let discount: Double?
    let overrides: [Override]?

    private enum CodingKeys: String, CodingKey {
        case prompt, completion, audio, image, request, discount, overrides
        case inputCacheRead = "input_cache_read"
        case inputCacheWrite = "input_cache_write"
        case inputCacheWriteOneHour = "input_cache_write_1h"
        case internalReasoning = "internal_reasoning"
        case webSearch = "web_search"
    }
}

extension OpenRouterPricing {
    /// The prices in a `pricing` object, or `nil` when it lacks a prompt or completion price or has a negative one,
    /// which OpenRouter sends for a model whose price depends on the request, such as a router.
    ///
    /// An override whose time window isn't a time of day, or that changes none of the prices kept here, is left out.
    init?(_ payload: PricingPayload) {
        guard let prompt = Self.price(payload.prompt), let completion = Self.price(payload.completion) else { return nil }
        self.init(
            prompt: prompt,
            completion: completion,
            cacheRead: Self.price(payload.inputCacheRead),
            cacheWrite: Self.price(payload.inputCacheWrite),
            cacheWriteOneHour: Self.price(payload.inputCacheWriteOneHour),
            reasoning: Self.price(payload.internalReasoning),
            audio: Self.price(payload.audio),
            image: Self.price(payload.image),
            request: Self.price(payload.request),
            webSearch: Self.price(payload.webSearch),
            overrides: (payload.overrides ?? []).compactMap(Override.init)
        )
    }

    /// A price from OpenRouter's decimal text, or `nil` for a negative one or text that isn't a number.
    static func price(_ text: String?) -> Decimal? {
        guard let text, let price = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), price >= 0 else {
            return nil
        }
        return price
    }
}

extension OpenRouterPricing.Override {
    /// The override in a `pricing` object, or `nil` when its window isn't a time of day or it changes no price.
    fileprivate init?(_ payload: PricingPayload.Override) {
        let prices =
            [payload.prompt, payload.completion, payload.inputCacheRead, payload.inputCacheWrite]
            + [payload.inputCacheWriteOneHour, payload.audio]
        guard prices.contains(where: { OpenRouterPricing.price($0) != nil }) else { return nil }
        var hours: OpenRouterPricing.TimeWindow?
        if payload.utcStart != nil || payload.utcEnd != nil {
            guard let start = Self.timeOfDay(clockNumber: payload.utcStart ?? 0),
                let end = Self.timeOfDay(clockNumber: payload.utcEnd ?? 2_400)
            else { return nil }
            hours = OpenRouterPricing.TimeWindow(start: start, end: end)
        }
        self.init(
            condition: Condition(
                // The threshold counts whole tokens, so a fraction rounds down without changing which prompts exceed it.
                promptTokensAbove: payload.minPromptTokens.map { Int($0.rounded(.down)) },
                weekdays: payload.utcDays.map { Set($0.compactMap(Self.weekday)) },
                hours: hours
            ),
            prompt: OpenRouterPricing.price(payload.prompt),
            completion: OpenRouterPricing.price(payload.completion),
            cacheRead: OpenRouterPricing.price(payload.inputCacheRead),
            cacheWrite: OpenRouterPricing.price(payload.inputCacheWrite),
            cacheWriteOneHour: OpenRouterPricing.price(payload.inputCacheWriteOneHour),
            audio: OpenRouterPricing.price(payload.audio)
        )
    }

    /// The time after midnight of an `HHMM` clock number, such as 1h30m for `130`, or `nil` when the number isn't a
    /// time from 00:00 to 24:00.
    private static func timeOfDay(clockNumber: Double) -> Duration? {
        guard clockNumber.isFinite, clockNumber >= 0, clockNumber == clockNumber.rounded() else { return nil }
        let (hours, minutes) = Int(clockNumber).quotientAndRemainder(dividingBy: 100)
        guard (0...24).contains(hours), (0..<60).contains(minutes), hours < 24 || minutes == 0 else { return nil }
        return .seconds(hours * 3_600 + minutes * 60)
    }

    /// The day an override names, such as `monday`, or `nil` for a name OpenRouter didn't use before, which no request
    /// matches.
    private static func weekday(_ name: String) -> Locale.Weekday? {
        switch name {
        case "sunday": .sunday
        case "monday": .monday
        case "tuesday": .tuesday
        case "wednesday": .wednesday
        case "thursday": .thursday
        case "friday": .friday
        case "saturday": .saturday
        default: nil
        }
    }
}
