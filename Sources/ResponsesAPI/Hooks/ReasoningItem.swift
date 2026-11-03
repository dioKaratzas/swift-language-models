package import LanguageModels

/// One of an answer's `reasoning` output items, as a later request's input sends it back: the item the stream's
/// `response.output_item.done` carried, with members such as `type`, `id`, `summary` and `encrypted_content`, and
/// every other member the provider sent.
///
/// A dialect whose ``ResponsesDialect/ReplayMembers`` is this type sends each answer's reasoning items back as they
/// came. Only the format creates one.
package struct ReasoningItem: Encodable, Sendable, Equatable {
    /// The item, as the provider sent it.
    package let json: JSONValue

    init(_ json: JSONValue) {
        self.json = json
    }

    /// Whether the item carries its reasoning encrypted, which a request that the provider doesn't store needs, since
    /// the provider can't look the item up by its id.
    var hasEncryptedContent: Bool {
        if case .string(let content)? = json["encrypted_content"] { !content.isEmpty } else { false }
    }

    package func encode(to encoder: any Encoder) throws {
        try json.encode(to: encoder)
    }
}
