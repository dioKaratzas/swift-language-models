package import FoundationModels
package import LanguageModels

extension ChatCompletionsExecutor {
    /// A request's body as the format wrote it, which the provider changes before it's sent.
    ///
    /// The format writes its members in a fixed order: `model`, `messages`, `stream`, the session's `tools` and
    /// `tool_choice`, `response_format`, `temperature`, `top_p`, `seed`, `max_completion_tokens` and `metadata`, each
    /// only when the request sets it. A provider adds its own members, leaves out what its models don't take, and puts
    /// the members in its own order, so the bytes a host caches stay the same from one request to the next.
    package struct Body {
        /// The body's members, in the order they're sent.
        package var members: JSONObject

        /// Whether a message carries a PDF.
        package let carriesPDF: Bool

        /// What the request leaves out or changes from what the app asked for.
        private(set) var adjustments: [APIFormat.Adjustment]

        /// Whether the body already sends the portable schema, so a host's rejection of a constraint isn't retried.
        private(set) var sendsPortableSchema = false

        /// The request's schema, which the portable form is made from.
        let schema: GenerationSchema?

        init(members: JSONObject, carriesPDF: Bool, adjustments: [APIFormat.Adjustment], schema: GenerationSchema?) {
            self.members = members
            self.carriesPDF = carriesPDF
            self.adjustments = adjustments
            self.schema = schema
        }

        /// Leaves out the members of the given keys that the provider's models don't list, and notes them, in the
        /// order the body has them, so the log names them.
        ///
        /// - Parameters:
        ///   - keys: The keys of the members that go out only when the models list them.
        ///   - lists: Whether the models list a member's key.
        package mutating func leaveOut(_ keys: Set<String>, unlessListed lists: (String) -> Bool) {
            let unlisted = members.members.map(\.key).filter { keys.contains($0) && !lists($0) }
            guard !unlisted.isEmpty else { return }
            for key in unlisted { members[key] = nil }
            adjustments.append(.unlistedParameters(unlisted))
        }

        /// Notes a reasoning level sent as another effort, or left out when no effort the models accept is near it.
        package mutating func noteMovedEffort(requested: String, sent: String?) {
            adjustments.append(.movedEffort(requested: requested, sent: sent))
        }

        /// Sends the response schema in portable form from the start, which carries its constraints in descriptions, as
        /// for a host known to reject them.
        ///
        /// - Throws: `LanguageModelError` when the schema can't be encoded.
        package mutating func sendPortableSchema() throws {
            guard let schema, members[ChatCompletionRequest.Key.responseFormat] != nil else { return }
            members[ChatCompletionRequest.Key.responseFormat] = try ChatCompletionRequest.jsonSchemaFormat(schema, portable: true)
            sendsPortableSchema = true
        }

        /// Adds members to the last content part of the last instructions, such as a cache mark, so the tools and
        /// instructions before it are cached on the host.
        package mutating func markLastInstructions(with marks: JSONObject) {
            guard case .array(var messages)? = members[ChatCompletionRequest.Key.messages],
                let index = messages.lastIndex(where: { $0["role"] == ChatCompletionRequest.Messages.Role.system.json }),
                case .object(var message) = messages[index]
            else { return }
            var parts: [JSONValue] =
                switch message["content"] {
                case .array(let parts)?: parts
                case .string(let text)?: [.textPart(text)]
                default: []
                }
            guard case .object(var last)? = parts.last else { return }
            for mark in marks.members { last[mark.key] = mark.value }
            parts[parts.count - 1] = .object(last)
            message["content"] = .array(parts)
            messages[index] = .object(message)
            members[ChatCompletionRequest.Key.messages] = .array(messages)
        }
    }
}
