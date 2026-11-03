import APIFormat
import Foundation
import FoundationModels
import LanguageModels
import os

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
        logSending(completion.body, log: log)
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
            logFinished(answer, log: log)
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
        var portableSchemaBody = completion.portableSchemaBody
        while true {
            let rejected: ProviderHTTP.Failure
            do {
                return try await http.stream(urlRequest) { log.retrying(status: $0, after: $1) }
            } catch let failure as ProviderHTTP.Failure {
                rejected = failure
            }
            if let body = portableSchemaBody,
                SchemaConstraint.isRejected(status: rejected.status, message: String(decoding: rejected.body, as: UTF8.self))
            {
                log.retryingWithPortableSchema(host: nil)
                urlRequest.httpBody = body.data
                portableSchemaBody = nil
                continue
            }
            let failure = ChatCompletionsFailure<Dialect>(
                .rejected(rejected.rejection(as: Dialect.ErrorBody.self)), imageEntries: completion.imageEntries)
            throw dialect.error(for: failure).error
        }
    }

    /// Logs at `debug` what the request sends: the model and the names of the options, never the transcript.
    private func logSending(_ body: JSONValue, log: OperationLog) {
        guard let logger = Dialect.logger(.debug) else { return }
        let options = if case .object(let body) = body { body.members.map(\.key) } else { [String]() }
        let sent = options.filter { !Self.nonOptions.contains($0) }.joined(separator: ", ")
        logger.debug("\(log.label, privacy: .public) to \(dialect.modelID.rawValue, privacy: .public); sends \(sent, privacy: .public)")
    }

    /// Logs at `debug` which model and host answered, why the answer ended, the time to its first token and the
    /// request's whole time.
    private func logFinished(_ answer: AnswerStream<Dialect>, log: OperationLog) {
        guard let logger = Dialect.logger(.debug) else { return }
        let host = dialect.facts(of: answer.state).host
        logger.debug(
            """
            \(log.label, privacy: .public) answered by \(answer.facts.model ?? "an unnamed model", privacy: .public) on \
            \(host ?? "an unnamed host", privacy: .public) in \(log.elapsedMilliseconds) ms, first token after \
            \(log.firstTokenDelay, privacy: .public); finish reason \(answer.facts.finishReason?.rawValue ?? "none", privacy: .public)
            """
        )
    }

    /// The path of the chat completions call under the provider's base URL.
    private static var path: String { "chat/completions" }

    /// The body's members that aren't options: the model and the transcript.
    private static var nonOptions: Set<String> { [MemberKey.model.rawValue, MemberKey.messages.rawValue, MemberKey.stream.rawValue] }
}
