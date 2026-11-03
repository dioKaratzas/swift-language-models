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
        try await OperationLog(request: request.id, logger: Dialect.logger).run { log in
            let response = try ResponsesRequest(request, dialect: dialect)
            log.sending(response.body, to: dialect.modelID.rawValue, leavingOut: Self.nonOptions)
            for adjustment in response.adjustments {
                log.report(adjustment, model: dialect.modelID.rawValue, provider: Dialect.name)
            }
            let (bytes, responseHeaders) = try await open(response, request: request, log: log)
            var answer = AnswerStream(
                channel: channel, dialect: dialect, headers: responseHeaders, imageEntries: response.imageEntries,
                requiresCompleteAnswer: request.schema != nil)
            _ = try await log.read(bytes, into: &answer)
            try await answer.finish()
            log.finished(answer.report, host: dialect.facts(of: answer.state).host)
            return DetailedLanguageModelAnswer(responseText: answer.responseText)
        }
    }

    /// Sends the request and opens its response stream, and sends it once more with the portable schema when the host
    /// rejects a constraint of the full one.
    ///
    /// - Returns: The stream, and the headers of its response.
    private func open(
        _ response: ResponsesRequest,
        request: LanguageModelExecutorGenerationRequest,
        log: OperationLog
    ) async throws -> (URLSession.AsyncBytes, ResponseHeaders) {
        do {
            return try await dialect.connection.openEventStream(
                body: response.body, portableSchemaBody: response.portableSchemaBody, headers: dialect.headers(HeaderContext(request)),
                url: { try dialect.baseURL.appending(path: Self.path) }, log: log)
        } catch let rejected as ProviderHTTP.Failure {
            let failure = ResponsesFailure<Dialect>(
                .rejected(rejected.rejection(as: Dialect.ErrorBody.self)), imageEntries: response.imageEntries)
            throw dialect.error(for: failure).error
        }
    }

    /// The path of the responses call under the provider's base URL.
    private static var path: String { "responses" }

    /// The body's members that aren't options: the model, the input and `stream`.
    private static var nonOptions: Set<String> { [MemberKey.model.rawValue, MemberKey.input.rawValue, MemberKey.stream.rawValue] }
}
