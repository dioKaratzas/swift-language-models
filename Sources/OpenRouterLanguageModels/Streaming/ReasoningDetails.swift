import Foundation
import FoundationModels
import LanguageModels

/// OpenRouter's `reasoning_details`: the reasoning a model produced, in the form OpenRouter needs back on later
/// turns.
///
/// The details are stored in a reasoning entry's signature, and the entry's metadata names OpenRouter as its
/// `ReasoningOrigin`, so only reasoning that OpenRouter wrote is sent back. The metadata also names the model that
/// wrote it, under `OpenRouterMetadataKey.model`, so reasoning a fallback wrote isn't sent to another model.
struct ReasoningDetails: Sendable, Equatable {
    private(set) var details: [JSONValue] = []

    /// Adds the details of one stream delta.
    ///
    /// Models stream one reasoning block as many deltas, often with the same `index`, so blocks are joined by type: a
    /// text detail continues the previous text detail until a signature closes it, a summary continues the previous
    /// summary, and every other detail, such as encrypted reasoning, stands alone.
    mutating func append(_ delta: JSONValue) {
        guard case .object(let detail) = delta else { return }
        let kind = delta.reasoningKind
        guard case .object(var last)? = details.last, details.last?.reasoningKind == kind else {
            details.append(delta)
            return
        }
        switch kind {
        case .text? where last["signature"]?.stringValue == nil:
            last["text"] = .string((last["text"]?.stringValue ?? "") + (detail["text"]?.stringValue ?? ""))
            for key in ["signature", "format"] where last[key]?.stringValue == nil && detail[key]?.stringValue != nil {
                last[key] = detail[key]
            }
        case .summary?:
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
            switch detail.reasoningKind {
            case .text?: detail["text"]?.stringValue
            case .summary?: detail["summary"]?.stringValue
            default: nil
            }
        }.joined()
    }

    /// The model that wrote a reasoning entry, as its answer named it, or `nil` when the entry doesn't say.
    static func writer(of reasoning: Transcript.Reasoning) -> String? {
        if case .string(let model)? = reasoning.metadata[OpenRouterMetadataKey.model]?.kind { model } else { nil }
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
            let format = detail["format"]?.stringValue.map(Format.init) ?? .anthropic
            return !format.requiresSignedText || detail["signature"]?.stringValue != nil
        }
    }
}

extension ReasoningDetails {
    /// What a detail holds, from its `type`. Other kinds, such as encrypted reasoning, stay opaque.
    struct Kind: RawRepresentable, Hashable, Sendable {
        /// Reasoning text, which may carry a signature.
        static let text = Self(rawValue: "reasoning.text")

        /// A summary of the reasoning.
        static let summary = Self(rawValue: "reasoning.summary")

        let rawValue: String
    }

    /// Whose reasoning a detail is, from its `format`.
    struct Format: RawRepresentable, Hashable, Sendable {
        /// Anthropic's.
        static let anthropic = Self(rawValue: "anthropic-claude-v1")

        /// Google Gemini's.
        static let gemini = Self(rawValue: "google-gemini-v1")

        let rawValue: String

        /// Whether the provider rejects reasoning text sent back without its signature.
        var requiresSignedText: Bool { self == .anthropic || self == .gemini }
    }
}

extension JSONValue {
    /// The kind of a reasoning detail.
    fileprivate var reasoningKind: ReasoningDetails.Kind? {
        self["type"]?.stringValue.map(ReasoningDetails.Kind.init)
    }
}
