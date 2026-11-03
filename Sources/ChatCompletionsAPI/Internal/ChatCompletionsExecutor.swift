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
        var log = OperationLog(request: request.id, logger: Dialect.logger)
        do {
            return try await respond(to: request, streamingInto: channel, log: &log)
        } catch {
            log.failed(error)
            throw error
        }
    }

    private func respond(
        to request: LanguageModelExecutorGenerationRequest,
        streamingInto channel: LanguageModelExecutorGenerationChannel,
        log: inout OperationLog
    ) async throws -> DetailedLanguageModelAnswer {
        let completion = try ChatCompletionRequest(request, dialect: dialect)
        log.sending(completion.body, to: dialect.modelID.rawValue, leavingOut: Self.nonOptions)
        for adjustment in completion.adjustments {
            log.report(adjustment, model: dialect.modelID.rawValue, provider: Dialect.name)
        }
        do {
            let connection = dialect.connection
            let authHeaders = try await connection.authentication.requestHeaders()
            let headers = dialect.headers(HeaderContext(request))
            let url = try dialect.baseURL.appending(path: Self.path)
            var urlRequest = ProviderHTTP.request(
                url: url, method: HTTPMethod.post, body: completion.body.data, accept: MediaType.eventStream,
                authHeaders: authHeaders, headers: headers, idleTimeout: connection.idleTimeout)
            let (bytes, responseHeaders) = try await open(&urlRequest, completion: completion, http: connection.http, log: log)
            var answer = AnswerStream(
                channel: channel, dialect: dialect, headers: responseHeaders, imageEntries: completion.imageEntries,
                requiresCompleteAnswer: request.schema != nil)
            var isComplete = false
            for try await event in ServerSentEvent.Events(bytes) {
                try Task.checkCancellation()
                if try await answer.receive(event) {
                    isComplete = true
                    break
                }
                if answer.hasOutput { log.receivedToken() }
            }
            try Task.checkCancellation()
            try await answer.finish(isComplete: isComplete)
            log.finished(answer.facts, host: dialect.facts(of: answer.state).host)
            return DetailedLanguageModelAnswer(responseText: answer.responseText)
        } catch let error as URLError {
            throw error.thrownError
        }
    }

    /// Opens the response stream, and opens it once more with the portable schema when the host rejects a constraint
    /// of the full one.
    ///
    /// - Returns: The stream, and the headers of its response.
    private func open(
        _ urlRequest: inout URLRequest,
        completion: ChatCompletionRequest,
        http: ProviderHTTP,
        log: OperationLog
    ) async throws -> (URLSession.AsyncBytes, ResponseHeaders) {
        do {
            return try await http.openStream(&urlRequest, portableSchemaBody: completion.portableSchemaBody, log: log)
        } catch let rejected as ProviderHTTP.Failure {
            let failure = ChatCompletionsFailure<Dialect>(
                .rejected(rejected.rejection(as: Dialect.ErrorBody.self)), imageEntries: completion.imageEntries)
            throw dialect.error(for: failure).error
        }
    }

    /// The path of the chat completions call under the provider's base URL.
    private static var path: String { "chat/completions" }

    /// The body's members that aren't options: the model and the transcript.
    private static var nonOptions: Set<String> { [MemberKey.model.rawValue, MemberKey.messages.rawValue, MemberKey.stream.rawValue] }
}
