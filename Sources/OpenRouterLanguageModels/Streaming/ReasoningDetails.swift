import Foundation
import FoundationModels
import LanguageModels

/// OpenRouter's `reasoning_details`: the reasoning a model produced, in the form OpenRouter needs back on later
/// turns.
///
/// The details are stored in a reasoning entry's signature, and the entry's metadata names OpenRouter as its
/// `ReasoningOrigin`, so only reasoning that OpenRouter wrote is sent back. The metadata also names the model that
/// wrote it, under `LanguageModelMetadataKey.model`, so reasoning a fallback wrote isn't sent to another model.
struct ReasoningDetails: Sendable, Equatable {
    private(set) var details: [JSONValue] = []

    /// Adds the details of one stream delta.
    ///
    /// Models stream one reasoning block as many deltas, with the same `index`, so a delta continues the previous
    /// detail of its type unless its `index` or `id` names another block: a text detail continues until a signature
    /// closes it, a summary continues, and every other detail, such as encrypted reasoning, stands alone.
    mutating func append(_ delta: JSONValue) {
        guard case .object(let detail) = delta else { return }
        let kind = delta.reasoningKind
        guard case .object(var last)? = details.last, details.last?.reasoningKind == kind, Self.isSameBlock(last, detail)
        else {
            details.append(delta)
            return
        }
        switch kind {
        case .text? where last["signature"]?.stringValue == nil:
            last["text"] = .string((last["text"]?.stringValue ?? "") + (detail["text"]?.stringValue ?? ""))
            Self.fill(&last, from: detail, keys: ["signature", "format", "id"])
        case .summary?:
            last["summary"] = .string((last["summary"]?.stringValue ?? "") + (detail["summary"]?.stringValue ?? ""))
            Self.fill(&last, from: detail, keys: ["format", "id"])
        default:
            details.append(delta)
            return
        }
        details[details.count - 1] = .object(last)
    }

    /// Whether a delta continues the last detail's block: neither its `index` nor its `id` names another one.
    private static func isSameBlock(_ last: JSONObject, _ detail: JSONObject) -> Bool {
        if let index = detail["index"], let lastIndex = last["index"], index != lastIndex { return false }
        if let id = detail["id"]?.stringValue, let lastID = last["id"]?.stringValue, id != lastID { return false }
        return true
    }

    /// Sets each of the keys that the last detail lacks and the delta has.
    private static func fill(_ last: inout JSONObject, from detail: JSONObject, keys: [String]) {
        for key in keys where last[key]?.stringValue == nil && detail[key]?.stringValue != nil {
            last[key] = detail[key]
        }
    }

    /// The details as the signature of a reasoning entry.
    var signature: Data {
        JSONValue.array(details).data
    }

    /// The text a person can read in one delta's details: reasoning text and summaries, not encrypted blobs.
    static func readableText(in delta: [JSONValue]) -> String {
        delta.compactMap { detail in
            switch detail.reasoningKind {
            case .text?: detail["text"]?.stringValue
            case .summary?: detail["summary"]?.stringValue
            default: nil
            }
        }.joined()
    }

    /// Whether a reasoning entry's reasoning came as text alone: without details, or with an empty list of them.
    static func isTextAlone(_ reasoning: Transcript.Reasoning) -> Bool {
        guard let signature = reasoning.signature else { return true }
        return (try? JSONValue(json: signature)) == .array([])
    }

    /// The details to send back for a reasoning entry, or `nil` when OpenRouter didn't write the entry.
    ///
    /// Anthropic and Gemini reject reasoning text without its signature, so unsigned text details in their formats are
    /// dropped. A detail without a format counts as Anthropic's, as OpenRouter treats it.
    static func replayed(from reasoning: Transcript.Reasoning) -> [JSONValue]? {
        guard ReasoningOrigin(of: reasoning) == .openRouter, let signature = reasoning.signature,
            case .array(let details)? = try? JSONValue(json: signature)
        else { return nil }
        return details.filter { detail in
            guard detail.reasoningKind == .text else { return true }
            let format = detail["format"]?.stringValue.map(Format.init(rawValue:)) ?? .anthropic
            return !format.requiresSignedText || detail["signature"]?.stringValue != nil
        }
    }
}

extension ReasoningDetails {
    /// What a detail holds, from its `type`. Other kinds, such as encrypted reasoning, stay opaque.
    fileprivate struct Kind: ProviderVocabulary {
        /// Reasoning text, which may carry a signature.
        static let text: Self = "reasoning.text"

        /// A summary of the reasoning.
        static let summary: Self = "reasoning.summary"

        let rawValue: String
    }

    /// Whose reasoning a detail is, from its `format`.
    fileprivate struct Format: ProviderVocabulary {
        /// Anthropic's.
        static let anthropic: Self = "anthropic-claude-v1"

        /// Google Gemini's.
        static let gemini: Self = "google-gemini-v1"

        let rawValue: String

        /// Whether the provider rejects reasoning text sent back without its signature.
        var requiresSignedText: Bool { self == .anthropic || self == .gemini }
    }
}

extension JSONValue {
    /// The kind of a reasoning detail.
    fileprivate var reasoningKind: ReasoningDetails.Kind? {
        self["type"]?.stringValue.map(ReasoningDetails.Kind.init(rawValue:))
    }
}
