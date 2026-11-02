package import Foundation
package import FoundationModels
package import LanguageModels
package import UniformTypeIdentifiers

/// A service that takes OpenAI's Chat Completions format, which ``ChatCompletionsExecutor`` sends requests to.
///
/// A provider names itself, its base URL and the model a request is for. The executor does the rest: it builds the
/// body from Foundation Models' request, sends it, retries once when a gateway is briefly unavailable and once with
/// the portable schema when a host rejects a constraint, streams the answer into Foundation Models' channel, maps
/// failures and logs. Every other requirement has a default that keeps the format's own behavior, and a provider
/// implements only those its service changes: its headers, members it adds to the finished body, attachments only it
/// takes, the reasoning it sends back, what its chunks carry beyond the format's, and its errors.
///
/// A provider's own types, such as its model, errors and options, never name this protocol or the executor; only the
/// provider's adapter does, so moving the provider to another format replaces the adapter and nothing else.
package protocol ChatCompletionsProvider: Sendable {
    /// What the provider tracks across one streamed answer, from its own members of each chunk.
    associatedtype Stream: Sendable = Void

    /// The provider's name, as errors and the log name it, such as `OpenRouter`. Saved transcripts keep the default
    /// ``reasoningOrigin``, which derives from it, so it never changes.
    var name: String { get }

    /// Where the provider's API lives; requests go to `chat/completions` under it.
    ///
    /// - Throws: The provider's error when the URL isn't valid.
    var baseURL: URL { get throws }

    /// The id the body's `model` names.
    var modelID: String { get }

    /// The origin the reasoning entries of the provider's answers carry, so that only its own reasoning goes back. The
    /// default is the provider's name in lowercase.
    var reasoningOrigin: ReasoningOrigin { get }

    /// The headers for a request: the ones that authenticate it, then the provider's own, which take precedence. The
    /// default sends none.
    ///
    /// - Throws: What authenticating the request throws.
    func headers(for request: LanguageModelExecutorGenerationRequest) async throws -> [String: String]

    /// Changes the finished body, as the format wrote it, before it's sent: adding the provider's own members,
    /// leaving out what its models don't take and putting the members in the provider's order. The default leaves it
    /// as it is.
    ///
    /// - Throws: `LanguageModelError` when the provider can't send the request.
    func transformBody(_ body: inout Body, for request: LanguageModelExecutorGenerationRequest) throws

    /// Checks that the provider's models take an attachment, before the format reads it. The default takes every one.
    ///
    /// - Throws: `LanguageModelError` for an attachment a model doesn't take.
    func check(_ attachment: Transcript.AttachmentSegment, in entry: Transcript.Entry) throws

    /// The content part for data of a kind the format has no part for, or `nil` for a kind the provider doesn't take
    /// either, which is the default.
    func contentPart(for data: Data, type: UTType, in entry: Transcript.Entry) -> JSONValue?

    /// Whether a reasoning entry goes back in a later request. The default sends back the entries of the provider's
    /// own ``reasoningOrigin``.
    func replays(_ reasoning: Transcript.Reasoning) -> Bool

    /// The members an assistant message carries after its content for the reasoning it sends back. A member whose
    /// value is an empty list or empty text carries no reasoning, so an answer with nothing else isn't sent back. The
    /// default sends none.
    ///
    /// - Parameter reasoning: The answer's reasoning entries that go back, in their order.
    /// - Returns: The members.
    func assistantMembers(replaying reasoning: [Transcript.Reasoning]) -> JSONObject

    /// Starts what the provider tracks across one answer.
    ///
    /// - Parameter response: The response whose stream carries the answer.
    /// - Returns: The provider's state before the answer's first chunk.
    func stream(for response: HTTPURLResponse?) -> Stream

    /// Reads the provider's own members of one chunk, in the order chunks arrive. The default reads none.
    ///
    /// - Parameters:
    ///   - chunk: The chunk.
    ///   - stream: What the provider tracks across the answer.
    /// - Returns: What the chunk adds to the answer beyond the format's own members.
    /// - Throws: An error when the chunk isn't what the provider sends, which ends the answer as a chunk that couldn't
    ///   be read.
    func observe(_ chunk: Chunk, in stream: inout Stream) throws -> ChunkOutput

    /// The facts the provider adds to the answer once it's over, or to an error before then. The default adds none.
    func facts(of stream: Stream) -> Facts

    /// The error a failure becomes. The default throws the failure itself.
    func error(for failure: Failure) -> any Error
}

extension ChatCompletionsProvider {
    /// The body a provider changes before it's sent.
    package typealias Body = ChatCompletionsExecutor<Self>.Body

    /// A streamed chunk, as the provider reads it.
    package typealias Chunk = ChatCompletionsExecutor<Self>.Chunk

    /// What a chunk's provider members add to the answer.
    package typealias ChunkOutput = ChatCompletionsExecutor<Self>.ChunkOutput

    /// What the provider adds to an answer's facts.
    package typealias Facts = ChatCompletionsExecutor<Self>.Facts

    /// Why a request failed.
    package typealias Failure = ChatCompletionsExecutor<Self>.Failure

    package var reasoningOrigin: ReasoningOrigin { ReasoningOrigin(rawValue: name.lowercased()) }

    package func headers(for request: LanguageModelExecutorGenerationRequest) async throws -> [String: String] { [:] }

    package func transformBody(_ body: inout Body, for request: LanguageModelExecutorGenerationRequest) throws {}

    package func check(_ attachment: Transcript.AttachmentSegment, in entry: Transcript.Entry) throws {}

    package func contentPart(for data: Data, type: UTType, in entry: Transcript.Entry) -> JSONValue? { nil }

    package func replays(_ reasoning: Transcript.Reasoning) -> Bool {
        ReasoningOrigin(of: reasoning) == reasoningOrigin
    }

    package func assistantMembers(replaying reasoning: [Transcript.Reasoning]) -> JSONObject { [:] }

    package func observe(_ chunk: Chunk, in stream: inout Stream) throws -> ChunkOutput { ChunkOutput() }

    package func facts(of stream: Stream) -> Facts { Facts() }

    package func error(for failure: Failure) -> any Error { failure }
}

extension ChatCompletionsProvider where Stream == Void {
    package func stream(for response: HTTPURLResponse?) {}
}
