import Foundation
package import FoundationModels
package import LanguageModels

/// Why a request failed, as a dialect's ``ChatCompletionsDialect/error(for:)`` reads it before it becomes the
/// provider's error.
///
/// Only the format's executor creates one.
package struct ChatCompletionsFailure<Dialect: ChatCompletionsDialect>: Error {
    /// What failed.
    package enum Kind: Sendable {
        /// A response whose status isn't a success, after the one retry.
        case rejected(HTTPRejection<Dialect.ErrorBody>)

        /// An error event in the stream, which arrives after the response's HTTP 200: the event's `error` object.
        case errorEvent(Dialect.ErrorBody)

        /// A response the format couldn't use.
        case unusableResponse(Problem)

        /// An answer whose finish reason, `error`, says the host failed while it generated.
        case failedAnswer
    }

    /// Why the format couldn't use a response.
    package enum Problem: Equatable, Sendable {
        /// An event's data isn't a chunk, with the reason it couldn't be read.
        case unreadableEvent(String)

        /// The stream ended before it was complete.
        case cutOff

        /// A tool call never got its name.
        case toolCallWithoutName

        /// A tool call's arguments aren't a whole JSON object, such as ones that stop partway.
        case incompleteToolArguments(toolName: String)

        /// The answer reached its token limit inside a tool call.
        case tokenLimitInToolCall
    }

    package let kind: Kind

    /// What the provider tracked across the answer when it failed, or `nil` before the answer started.
    package let state: Dialect.StreamState?

    /// The request's entries that carry an image, which an error for an image the host rejects names.
    package let imageEntries: [Transcript.Entry]

    init(_ kind: Kind, state: Dialect.StreamState? = nil, imageEntries: [Transcript.Entry]) {
        self.kind = kind
        self.state = state
        self.imageEntries = imageEntries
    }

    /// The format's own words for what went wrong: the status of a failed response, and a sentence for any other
    /// failure.
    package var message: String {
        switch kind {
        case .rejected(let rejection): HTTPURLResponse.localizedString(forStatusCode: rejection.status)
        case .errorEvent: "\(Dialect.name) sent an error."
        case .unusableResponse(let problem): problem.message(provider: Dialect.name)
        case .failedAnswer: "The model's response ended in an error."
        }
    }
}

extension ChatCompletionsFailure.Problem {
    /// What went wrong, as an error says it.
    ///
    /// - Parameter provider: The provider's name, such as `OpenRouter`.
    /// - Returns: A sentence for the error's message.
    func message(provider: String) -> String {
        switch self {
        case .unreadableEvent(let reason): "\(provider) sent an event that couldn't be read: \(reason)"
        case .cutOff: "The response ended before it was complete."
        case .toolCallWithoutName: "The model sent a tool call without its name."
        case .incompleteToolArguments(let toolName): "The model sent arguments for \(toolName) that aren't a whole JSON object."
        case .tokenLimitInToolCall: "The answer reached its token limit inside a tool call."
        }
    }
}
