package import FoundationModels
package import LanguageModels

/// How a provider speaks OpenAI's Responses format, which the format's executor sends requests in.
///
/// The executor owns the whole exchange: it builds the body from Foundation Models' request, authenticates and sends
/// it, retries once when a gateway is briefly unavailable and once with the portable schema when a host rejects a
/// constraint, streams the answer into Foundation Models' channel, maps a failed connection and logs. A dialect adds
/// only what its provider does differently, through hooks that each get what that hook needs and nothing else:
///
/// - ``headers(_:)``: headers beyond the authentication's.
/// - ``body(_:)``: the provider's own members, as ``BodyExtras``, and the few choices it makes about the format's.
/// - ``lists(_:)`` with ``listedMembers``: members sent only when the models take them.
/// - ``check(_:in:)`` with ``extraMedia``: the attachments its models take.
/// - ``instructionsRole``: the role the instructions go in.
/// - ``replays(_:)`` and ``replayMembers(_:)``: the reasoning it sends back, as ``ReplayMembers``.
/// - ``reasoningOrigin`` and ``phasesMetadataKey``: how its answers' reasoning and messages are tagged, so they go
///   back on later turns.
/// - ``streamState(_:)``, ``observe(_:into:)`` and ``facts(of:)``: what its events carry beyond the format's, as
///   ``EventExtras``, tracked across the answer in ``StreamState``.
/// - ``error(for:)``: what each failure becomes.
///
/// Every hook has a default that adds nothing, except ``error(for:)``, which turns failures into the provider's own
/// public error. A hook whose types the dialect sets has no default, unless the type is the format's own: a dialect
/// that sets ``EventExtras`` and doesn't read them in ``observe(_:into:)`` doesn't compile, while one that sets
/// ``ReplayMembers`` to ``ReasoningItem`` gets the format's ``replayMembers(_:)``. Implement the hooks that have a default in the extension that
/// declares the conformance: only there does a misspelled one draw a warning instead of silently keeping the default.
///
/// A request executor runs a dialect with
/// ``LanguageModels/DetailedLanguageModelRequestExecutor/respond(to:model:streamingInto:as:)``, the format's only way
/// in.
package protocol ResponsesDialect: ProviderDialect {
    /// The provider's own members of a request's body. Their keys are ``MemberKey`` values, never the format's own.
    associatedtype BodyExtras: Encodable = NoMembers

    /// The input items that an answer's reasoning goes back as, each before the answer's message and function calls.
    /// ``ReasoningItem`` sends the answer's `reasoning` items back as the provider sent them; the default sends none.
    associatedtype ReplayMembers: Encodable = NoMembers

    /// The provider's own members of a streamed event, decoded from the same JSON as the format's.
    associatedtype EventExtras: Decodable = NoMembers

    /// What the provider tracks across one streamed answer.
    associatedtype StreamState: Sendable = Void

    /// The origin the reasoning entries of the provider's answers carry, so that only its own reasoning goes back.
    /// Saved transcripts keep it, so it never changes. The default is the provider's name in lowercase, followed by
    /// `-responses`.
    static var reasoningOrigin: ReasoningOrigin { get }

    /// The metadata key under which an answer's response entry keeps the `phase` of each of its messages, such as
    /// `commentary` or `final_answer`, with the length of its text, so each message goes back with its phase on later
    /// turns. Saved transcripts keep it, so it never changes. The default is the provider's name with its first letter
    /// in lowercase, followed by `.phases`.
    static var phasesMetadataKey: String { get }

    /// The order of a body's members, the format's and the provider's, which a host's prompt cache depends on. A
    /// member it doesn't name goes after the ones it does, in the order it was written. The default is the format's
    /// order, ``MemberKey/formatOrder``.
    static var memberOrder: [MemberKey] { get }

    /// The members, the format's or the provider's, that go out only when ``lists(_:)`` says the models take them. A
    /// member left out is logged. The default is none.
    static var listedMembers: Set<MemberKey> { get }

    /// The kinds of data the provider takes as files beyond the format's PDF, in the order they're matched. The
    /// default is none.
    static var extraMedia: [MediaPart] { get }

    /// The role of the message the instructions go in. The default is `developer`.
    var instructionsRole: InstructionsRole { get }

    /// The provider's headers for a request, which take precedence over the authentication's. The default is none.
    func headers(_ context: HeaderContext) -> [HTTPHeaderName: String]

    /// Whether the models take a member of ``listedMembers``. The default takes every one.
    func lists(_ member: MemberKey) -> Bool

    /// Checks that the models take an attachment, before the format reads it. The default takes every one.
    ///
    /// - Throws: `LanguageModelError` for an attachment a model doesn't take.
    func check(_ attachment: AttachmentKind, in entry: Transcript.Entry) throws(LanguageModelError)

    /// The provider's members of a request's body, and its choices about the format's own.
    ///
    /// - Throws: `LanguageModelError` when the provider can't send the request.
    func body(_ context: BodyContext) throws(LanguageModelError) -> BodyPlan<BodyExtras>

    /// Whether one of the provider's own reasoning entries goes back in a later request. Reasoning another provider
    /// wrote never does. The default sends back every one.
    func replays(_ reasoning: Transcript.Reasoning) -> Bool

    /// The input items an answer's reasoning goes back as, before the answer's message and function calls.
    ///
    /// - Parameter reasoning: The answer's reasoning entries that go back, in their order.
    /// - Returns: The items, in their order.
    func replayMembers(_ reasoning: [ReplayedReasoning]) -> [ReplayMembers]

    /// What the provider tracks across one answer, before its first event.
    ///
    /// - Parameter headers: The headers of the response whose stream carries the answer.
    /// - Returns: The state before the answer's first event.
    func streamState(_ headers: ResponseHeaders) -> StreamState

    /// Reads the provider's members of one event, in the order events arrive.
    ///
    /// - Returns: What the event adds to the answer beyond the format's own members.
    func observe(_ extras: EventExtras, into state: inout StreamState) -> EventOutput

    /// The facts the provider adds to the answer once it's over, or to an error before then. A reasoning signature
    /// it returns replaces the format's, which holds the answer's `reasoning` items.
    func facts(of state: StreamState) -> AnswerFacts

    /// What a failure becomes: Foundation Models' error when it has a case for it, otherwise the provider's own.
    func error(for failure: ResponsesFailure<Self>) -> MappedError<ProviderError>
}

extension ResponsesDialect {
    package static var reasoningOrigin: ReasoningOrigin { ReasoningOrigin(rawValue: "\(name.lowercased())-responses") }

    package static var phasesMetadataKey: String { "\(name.prefix(1).lowercased())\(name.dropFirst()).phases" }

    package static var memberOrder: [MemberKey] { MemberKey.formatOrder }

    package static var listedMembers: Set<MemberKey> { [] }

    package static var extraMedia: [MediaPart] { [] }

    package var instructionsRole: InstructionsRole { .developer }

    package func headers(_ context: HeaderContext) -> [HTTPHeaderName: String] { [:] }

    package func lists(_ member: MemberKey) -> Bool { true }

    package func check(_ attachment: AttachmentKind, in entry: Transcript.Entry) throws(LanguageModelError) {}

    package func replays(_ reasoning: Transcript.Reasoning) -> Bool { true }
}

extension ResponsesDialect where BodyExtras == NoMembers {
    package func body(_ context: BodyContext) throws(LanguageModelError) -> BodyPlan<NoMembers> {
        BodyPlan(extras: NoMembers())
    }
}

extension ResponsesDialect where ReplayMembers == NoMembers {
    package func replayMembers(_ reasoning: [ReplayedReasoning]) -> [NoMembers] { [] }
}

extension ResponsesDialect where ReplayMembers == ReasoningItem {
    package func replayMembers(_ reasoning: [ReplayedReasoning]) -> [ReasoningItem] { reasoning.flatMap(\.items) }
}

extension ResponsesDialect where EventExtras == NoMembers {
    package func observe(_ extras: NoMembers, into state: inout StreamState) -> EventOutput { EventOutput() }
}

extension ResponsesDialect where StreamState == Void {
    package func streamState(_ headers: ResponseHeaders) {}

    package func facts(of state: Void) -> AnswerFacts { AnswerFacts() }
}
