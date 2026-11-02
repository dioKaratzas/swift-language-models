import Foundation
import LanguageModels

/// The `error` object OpenRouter sends in a failed response's body, or in a stream event with HTTP 200.
struct OpenRouterErrorResponse: Decodable, Sendable {
    /// The HTTP status as a number, or a provider's code as text.
    var code: JSONValue? = nil
    let message: String
    var metadata: JSONValue? = nil

    /// OpenRouter's kind of error, such as `context_length_exceeded`, or `nil` when the body doesn't name one.
    var errorType: OpenRouterError.Code? { metadata?["error_type"]?.stringValue.map(OpenRouterError.Code.init(rawValue:)) }

    /// The host that failed, such as `Anthropic`.
    var providerName: OpenRouterProviderName? { metadata?["provider_name"]?.stringValue.map(OpenRouterProviderName.init(rawValue:)) }

    /// Whether a 402 means too many requests are in flight at once, rather than no credits.
    var isInFlightBudget: Bool { limitSource == .inFlightBudget }

    /// The budget or limit the request ran into, such as a key's spending budget, when the body names one.
    var limitSource: LimitSource? { metadata?["limit_source"]?.stringValue.map(LimitSource.init(rawValue:)) }

    /// When a spending budget's window rolls over and its spend returns to zero, or `nil` for a lifetime budget.
    var budgetResetDate: Date? {
        guard let text = metadata?["resets_at"]?.stringValue else { return nil }
        return (try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)))
            ?? (try? Date(text, strategy: .iso8601))
    }

    /// Whether a 403 comes from OpenRouter's moderation or a guardrail, which name what they flagged, rather than from
    /// the key's permissions.
    var isModeration: Bool { ["reasons", "flagged_input", "patterns"].contains { metadata?[$0] != nil } }

    /// The status the code names, when it's a number.
    var status: Int? {
        switch code {
        case .integer(let status)?: status
        case .string(let text)?: Int(text)
        default: nil
        }
    }

    /// The code, when it's text rather than a number, such as a host's `server_error`.
    var textCode: String? {
        guard case .string(let text)? = code, Int(text) == nil, !text.isEmpty else { return nil }
        return text
    }

    /// The host's own message when it gave one, since OpenRouter's is often only "Provider returned error".
    var bestMessage: String {
        Self.message(in: metadata?["raw"]) ?? message
    }

    /// A message in a host's raw error: a string, a string of JSON, or an object with a message field.
    private static func message(in raw: JSONValue?) -> String? {
        switch raw {
        case .string(let text)?:
            guard let json = try? JSONValue(json: Data(text.utf8)), case .object = json else { return text.isEmpty ? nil : text }
            return message(in: json)
        case .object?:
            for field in ["message", "error", "detail", "details", "msg"] {
                if let found = message(in: raw?[field]) { return found }
            }
            return nil
        default:
            return nil
        }
    }

    /// A budget or limit that a request runs into.
    struct LimitSource: ProviderVocabulary {
        /// The most requests a key may have in flight at once.
        static let inFlightBudget: Self = "openrouter_in_flight_budget"

        let rawValue: String
    }

    /// The body of a failed response, `{"error": {…}}`.
    struct Envelope: Decodable {
        let error: OpenRouterErrorResponse
    }
}
