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
    var isInFlightBudget: Bool { metadata?["limit_source"]?.stringValue == "openrouter_in_flight_budget" }

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
        Self.message(in: metadata?["raw"]).flatMap { $0 == message ? nil : $0 } ?? message
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

    /// The body of a failed response, `{"error": {…}}`.
    struct Envelope: Decodable {
        let error: OpenRouterErrorResponse
    }
}
