import APIFormat
import Foundation
import FoundationModels
import LanguageModels

/// Sends a dialect's Chat Completions requests and streams each answer into Foundation Models.
struct ChatCompletionsExecutor<Dialect: ChatCompletionsDialect> {
    let dialect: Dialect

    /// Sends one request and streams its answer.
    func respond(
        to request: LanguageModelExecutorGenerationRequest,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws -> DetailedLanguageModelAnswer {
        try await OperationLog(request: request.id, logger: Dialect.logger).run { log in
            let completion = try ChatCompletionRequest(request, dialect: dialect)
            log.sending(completion.body, to: dialect.modelID.rawValue, leavingOut: Self.nonOptions)
            for adjustment in completion.adjustments {
                log.report(adjustment, model: dialect.modelID.rawValue, provider: Dialect.name)
            }
            let (bytes, responseHeaders) = try await open(completion, request: request, log: log)
            var answer = AnswerStream(
                channel: channel, dialect: dialect, headers: responseHeaders, imageEntries: completion.imageEntries,
                requiresCompleteAnswer: request.schema != nil)
            let isComplete = try await log.read(bytes, into: &answer)
            try await answer.finish(isComplete: isComplete)
            log.finished(answer.report, host: dialect.facts(of: answer.state).host)
            return DetailedLanguageModelAnswer(responseText: answer.responseText)
        }
    }

    /// Sends the request and opens its response stream, and sends it once more with the portable schema when the host
    /// rejects a constraint of the full one.
    ///
    /// - Returns: The stream, and the headers of its response.
    private func open(
        _ completion: ChatCompletionRequest,
        request: LanguageModelExecutorGenerationRequest,
        log: OperationLog
    ) async throws -> (URLSession.AsyncBytes, ResponseHeaders) {
        do {
            return try await dialect.connection.openEventStream(
                body: completion.body, portableSchemaBody: completion.portableSchemaBody, headers: dialect.headers(HeaderContext(request)),
                url: { try dialect.baseURL.appending(path: Self.path) }, log: log)
        } catch let rejected as ProviderHTTP.Failure {
            let failure = ChatCompletionsFailure<Dialect>(
                .rejected(rejected.rejection(as: Dialect.ErrorBody.self)), imageEntries: completion.imageEntries)
            throw dialect.error(for: failure).error
        }
    }

    /// The path of the chat completions call under the provider's base URL.
    private static var path: String { "chat/completions" }

    /// The body's members that aren't options: the model, the transcript and `stream`.
    private static var nonOptions: Set<String> { [MemberKey.model.rawValue, MemberKey.messages.rawValue, MemberKey.stream.rawValue] }
}
