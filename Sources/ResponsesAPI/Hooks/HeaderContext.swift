import APIFormat
import FoundationModels

/// What a dialect's ``ResponsesDialect/headers(_:)`` reads of a request.
///
/// Only the format's executor creates one.
package struct HeaderContext: Sendable {
    /// The id of the transcript's first prompt, which stays the same for the whole session, so a provider that keeps a
    /// session's requests on one host can send it as the session's id; `nil` before the first prompt.
    package let firstPromptID: String?

    init(_ request: LanguageModelExecutorGenerationRequest) {
        firstPromptID = request.transcript.firstPromptID
    }
}
