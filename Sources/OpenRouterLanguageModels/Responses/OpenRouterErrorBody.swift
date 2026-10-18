import Foundation
import LanguageModels

/// The `error` object OpenRouter sends in a failed response's body, or in a stream event with HTTP 200.
struct OpenRouterErrorBody: Decodable, Sendable {
    /// The HTTP status as a number, or a provider's code as text.
    let code: JSONValue?
    let message: String
    let metadata: JSONValue?

    /// OpenRouter's kind of error, such as `context_length_exceeded`.
    var errorType: String? { metadata?["error_type"]?.stringValue }

    /// The host that failed, such as `Anthropic`.
    var providerName: String? { metadata?["provider_name"]?.stringValue }

    /// The status the code names, when it's a number.
    var status: Int? {
        switch code {
        case .integer(let status)?: status
        case .string(let text)?: Int(text)
        default: nil
        }
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
        let error: OpenRouterErrorBody
    }
}
