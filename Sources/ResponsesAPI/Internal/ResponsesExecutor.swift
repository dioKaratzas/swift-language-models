import APIFormat
import Foundation
import FoundationModels
import LanguageModels

/// Sends a dialect's Responses requests and streams each answer into Foundation Models.
struct ResponsesExecutor<Dialect: ResponsesDialect> {
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
        let response = try ResponsesRequest(request, dialect: dialect)
        log.sending(response.body, to: dialect.modelID.rawValue, leavingOut: Self.nonOptions)
        for adjustment in response.adjustments {
            log.report(adjustment, model: dialect.modelID.rawValue, provider: Dialect.name)
        }
        do {
            let connection = dialect.connection
            let authHeaders = try await connection.authentication.requestHeaders()
            let headers = dialect.headers(HeaderContext(request))
            let url = try dialect.baseURL.appending(path: Self.path)
            var urlRequest = ProviderHTTP.request(
                url: url, method: HTTPMethod.post, body: response.body.data, accept: MediaType.eventStream,
                authHeaders: authHeaders, headers: headers, idleTimeout: connection.idleTimeout)
            let (bytes, responseHeaders) = try await open(&urlRequest, response: response, http: connection.http, log: log)
            var answer = AnswerStream(
                channel: channel, dialect: dialect, headers: responseHeaders, imageEntries: response.imageEntries,
                requiresCompleteAnswer: request.schema != nil)
            for try await event in ServerSentEvent.Events(bytes) {
                try Task.checkCancellation()
                if try await answer.receive(event) { break }
                if answer.hasOutput { log.receivedToken() }
            }
            try Task.checkCancellation()
            try await answer.finish()
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
        response: ResponsesRequest,
        http: ProviderHTTP,
        log: OperationLog
    ) async throws -> (URLSession.AsyncBytes, ResponseHeaders) {
        do {
            return try await http.openStream(&urlRequest, portableSchemaBody: response.portableSchemaBody, log: log)
        } catch let rejected as ProviderHTTP.Failure {
            let failure = ResponsesFailure<Dialect>(
                .rejected(rejected.rejection(as: Dialect.ErrorBody.self)), imageEntries: response.imageEntries)
            throw dialect.error(for: failure).error
        }
    }

    /// The path of the responses call under the provider's base URL.
    private static var path: String { "responses" }

    /// The body's members that aren't options: the model and the transcript.
    private static var nonOptions: Set<String> { [MemberKey.model.rawValue, MemberKey.input.rawValue, MemberKey.stream.rawValue] }
}
