import FoundationModels
package import LanguageModels

extension ReplayedReasoning {
    /// The answer's `reasoning` output items, which the format kept in the entry's signature, in their order; none for
    /// an entry whose signature the dialect wrote.
    package var items: [ReasoningItem] {
        ReasoningItem.items(inSignatureOf: entry)
    }
}

extension ReasoningItem {
    /// The `reasoning` items an entry's signature holds: a JSON array of them, as the format writes it.
    static func items(inSignatureOf entry: Transcript.Reasoning) -> [ReasoningItem] {
        guard let signature = entry.signature, case .array(let items)? = try? JSONValue(json: signature) else { return [] }
        return items.filter { $0["type"]?.stringValue == ResponsesRequest.ItemType.reasoning.rawValue }.map(ReasoningItem.init)
    }
}
