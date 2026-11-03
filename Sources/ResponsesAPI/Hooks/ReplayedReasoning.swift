import APIFormat
package import FoundationModels
import LanguageModels

/// One of an answer's reasoning entries that goes back in a later request, as a dialect's
/// ``ResponsesDialect/replayMembers(_:)`` reads it.
///
/// Only the format's executor creates one.
package struct ReplayedReasoning {
    /// The entry, with its signature and metadata.
    package let entry: Transcript.Reasoning

    /// The entry's text, or empty for a block the model wrote at the start of its answer's text, which goes back
    /// there instead.
    package let text: String

    /// The answer's `reasoning` output items, which the format kept in the entry's signature, in their order; none for
    /// an entry whose signature the dialect wrote.
    package let items: [ReasoningItem]

    init(_ entry: Transcript.Reasoning) {
        self.entry = entry
        text = TaggedReasoning.block(of: entry) == nil ? entry.segments.compactMap(\.text).joined() : ""
        items = ReasoningItem.items(inSignatureOf: entry)
    }
}

extension ReasoningItem {
    /// The `reasoning` items an entry's signature holds: a JSON array of them, as the format writes it.
    static func items(inSignatureOf entry: Transcript.Reasoning) -> [ReasoningItem] {
        guard let signature = entry.signature, case .array(let items)? = try? JSONValue(json: signature) else { return [] }
        return items.filter { $0["type"]?.stringValue == ResponsesRequest.ItemType.reasoning.rawValue }.map(ReasoningItem.init)
    }
}
