/// What a dialect's ``ResponsesDialect/body(_:)`` adds to a request's body, and the choices it makes about the
/// format's own members.
///
/// The format writes its members in a fixed order: `model`, `input`, `stream`, `store`, `include`, the session's
/// `tools` and `tool_choice`, `text`, `reasoning`, `temperature`, `top_p`, `max_output_tokens` and `metadata`, each only
/// when the request or the plan sets it. The plan adds the provider's members and makes the few choices a provider has
/// about the format's: it can't change the input or the settings the app asked for.
package struct BodyPlan<Extras: Encodable> {
    /// The provider's own members.
    package var extras: Extras

    /// Whether the session's tools, and with them `tool_choice`, go out.
    package var sessionTools = SessionTools.sent

    /// Tools that run on the provider's servers, sent after the session's in `tools`.
    package var serverTools: [any Encodable & Sendable] = []

    /// The form the response schema goes in.
    package var schema = SchemaForm.full

    /// The `reasoning` member, or `nil` to leave it out, so the model reasons as it does by default.
    package var reasoning: Reasoning?

    /// A reasoning level the provider sends as another effort, or leaves out, which the request logs.
    package var movedEffort: MovedEffort?

    /// Whether the provider keeps the response, as `store` asks.
    package var storage = Storage.automatic

    /// Whether the response carries each reasoning item's reasoning encrypted, as `include` asks, so the item can go
    /// back on later turns whether or not the provider keeps the response.
    package var asksForEncryptedReasoning = false

    /// Members added to `text` after its format, such as `verbosity`; `nil` for none.
    package var textExtras: (any Encodable & Sendable)?

    /// Members the request leaves out although the models list them, because the provider doesn't take them with the
    /// request's other settings, such as `temperature` while a model reasons. The request logs each one.
    package var leftOutMembers: Set<MemberKey> = []

    package init(extras: Extras) {
        self.extras = extras
    }

    /// Whether the session's tools go out.
    package enum SessionTools: Sendable {
        /// The session's tools go out as functions, with `tool_choice` when the app chose how they're called.
        case sent

        /// Neither the session's tools nor `tool_choice` go out, as for models that don't take tools.
        case leftOut
    }

    /// The form of the response schema.
    package enum SchemaForm: Sendable {
        /// The full schema, and the portable one only if the host rejects one of its constraints.
        case full

        /// The portable schema from the start, which carries its constraints in descriptions, as for a host known to
        /// reject them.
        case portable
    }

    /// Whether the provider keeps the response.
    package enum Storage: Sendable {
        /// `store` stays out of the body, so the provider's default applies.
        case automatic

        /// `store` is `true`.
        case stored

        /// `store` is `false`, so later turns send their reasoning items back encrypted.
        case notStored
    }

    /// The `reasoning` member: how hard the model reasons and what it reports of its reasoning. A value left `nil`
    /// stays out of the member.
    package struct Reasoning: Encodable, Sendable, Equatable {
        /// The effort, such as `low`, in the provider's word for it.
        package var effort: String?

        /// The summary of its reasoning the model writes, such as `auto`.
        package var summary: String?

        /// How the model reasons, such as `pro`.
        package var mode: String?

        package init(effort: String? = nil, summary: String? = nil, mode: String? = nil) {
            self.effort = effort
            self.summary = summary
            self.mode = mode
        }

        /// Whether the member carries no value, so it stays out of the body.
        var isEmpty: Bool {
            effort == nil && summary == nil && mode == nil
        }
    }

    /// A reasoning level sent as another effort, the nearest the models accept, or left out when none is near it.
    package struct MovedEffort: Sendable, Equatable {
        /// The level's own effort word.
        package let requested: String

        /// The effort sent instead, or `nil` when none is.
        package let sent: String?

        package init(requested: String, sent: String?) {
            self.requested = requested
            self.sent = sent
        }
    }
}
