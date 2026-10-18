import Foundation
import FoundationModels
import LanguageModels

/// OpenRouter's `reasoning_details`: the reasoning a model produced, in the form OpenRouter needs back on later
/// turns.
///
/// The details are stored in a reasoning entry's signature, and the entry is tagged in its metadata, so only
/// reasoning that OpenRouter wrote is sent back.
struct ReasoningDetails: Sendable, Equatable {
    /// The metadata key and value that mark a reasoning entry as OpenRouter's.
    static let metadataKey = "LanguageModels.provider"
    static let metadataValue = "openrouter"

    private(set) var details: [JSONValue] = []

    /// Adds the details of one stream delta.
    ///
    /// Models stream one reasoning block as many deltas, often with the same `index`, so blocks are joined by type: a
    /// text detail continues the previous text detail until a signature closes it, a summary continues the previous
    /// summary, and every other detail, such as encrypted reasoning, stands alone.
    mutating func append(_ delta: JSONValue) {
        guard case .object(let detail) = delta else { return }
        let type = detail["type"]?.stringValue
        guard case .object(var last)? = details.last, last["type"]?.stringValue == type else {
            details.append(delta)
            return
        }
        switch type {
        case "reasoning.text" where last["signature"]?.stringValue == nil:
            last["text"] = .string((last["text"]?.stringValue ?? "") + (detail["text"]?.stringValue ?? ""))
            for key in ["signature", "format"] where last[key]?.stringValue == nil && detail[key]?.stringValue != nil {
                last[key] = detail[key]
            }
        case "reasoning.summary":
            last["summary"] = .string((last["summary"]?.stringValue ?? "") + (detail["summary"]?.stringValue ?? ""))
            if last["format"]?.stringValue == nil, detail["format"]?.stringValue != nil { last["format"] = detail["format"] }
        default:
            details.append(delta)
            return
        }
        details[details.count - 1] = .object(last)
    }

    /// The details as the signature of a reasoning entry.
    var signature: Data {
        JSONValue.array(details).data
    }

    /// The text a person can read in one delta's details: reasoning text and summaries, not encrypted blobs.
    static func readableText(in delta: [JSONValue]) -> String {
        delta.compactMap { detail in
            switch detail["type"]?.stringValue {
            case "reasoning.text": detail["text"]?.stringValue
            case "reasoning.summary": detail["summary"]?.stringValue
            default: nil
            }
        }.joined()
    }

    /// The details to send back for a reasoning entry, or `nil` when OpenRouter didn't write the entry.
    ///
    /// Anthropic and Gemini reject reasoning text without its signature, so unsigned text details in their formats are
    /// dropped.
    static func replayed(from reasoning: Transcript.Reasoning) -> [JSONValue]? {
        guard case .string(metadataValue)? = reasoning.metadata[metadataKey]?.kind, let signature = reasoning.signature,
            case .array(let details)? = try? JSONValue(json: signature)
        else { return nil }
        return details.filter { detail in
            guard detail["type"]?.stringValue == "reasoning.text" else { return true }
            let needsSignature = ["anthropic-claude-v1", "google-gemini-v1"].contains(detail["format"]?.stringValue ?? "")
            return !needsSignature || detail["signature"]?.stringValue != nil
        }
    }
}
