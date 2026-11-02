package import Foundation
package import FoundationModels
package import LanguageModels

extension ChatCompletionsExecutor {
    /// Why a request failed, before it becomes the provider's error.
    package struct Failure: Error {
        /// What failed.
        package enum Kind: Sendable {
            /// A response whose status isn't a success, after the one retry.
            case response(ProviderHTTP.Failure)

            /// An error event in the stream, which arrives after the response's HTTP 200: the event's `error` object.
            case errorEvent(JSONValue)

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
        package let stream: Provider.Stream?

        /// The request's entries that carry an image, which an error for an image the host rejects names.
        package let imageEntries: [Transcript.Entry]

        /// The provider's name.
        private let provider: String

        init(_ kind: Kind, stream: Provider.Stream? = nil, provider: String, imageEntries: [Transcript.Entry]) {
            self.kind = kind
            self.stream = stream
            self.provider = provider
            self.imageEntries = imageEntries
        }

        /// What went wrong: the message of a failed response's or an error event's `error` object, and the format's own
        /// words for any other failure.
        package var message: String {
            switch kind {
            case .response(let failure):
                (try? ChatCompletionChunk.decoder.decode(APIFormat.ErrorBody.Envelope.self, from: failure.body).error.message)
                    ?? HTTPURLResponse.localizedString(forStatusCode: failure.status)
            case .errorEvent(let error):
                error["message"]?.stringValue ?? "\(provider) sent an error."
            case .unusableResponse(let problem):
                problem.message(provider: provider)
            case .failedAnswer:
                "The model's response ended in an error."
            }
        }
    }
}

extension ChatCompletionsExecutor.Failure: LocalizedError {
    package var errorDescription: String? { message }
}

extension ChatCompletionsExecutor.Failure.Problem {
    /// What went wrong, as an error says it.
    ///
    /// - Parameter provider: The provider's name, such as `OpenRouter`.
    /// - Returns: A sentence for the error's message.
    package func message(provider: String) -> String {
        switch self {
        case .unreadableEvent(let reason): "\(provider) sent an event that couldn't be read: \(reason)"
        case .cutOff: "The response ended before it was complete."
        case .toolCallWithoutName: "The model sent a tool call without its name."
        case .incompleteToolArguments(let toolName): "The model sent arguments for \(toolName) that aren't a whole JSON object."
        case .tokenLimitInToolCall: "The answer reached its token limit inside a tool call."
        }
    }
}
