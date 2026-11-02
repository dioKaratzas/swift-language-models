package import Foundation
package import FoundationModels
package import LanguageModels
import os

/// Sends a provider's Chat Completions requests and streams each answer into Foundation Models.
///
/// For each request the executor builds the body from Foundation Models' request, lets the provider change it, logs
/// what it sends and what it changed from what the app asked for, and sends it with the provider's headers. A request
/// is retried once, before any data arrives, when a gateway or host is briefly unavailable and its `Retry-After`, if
/// any, asks for 10 seconds or less, and once with the portable schema when the host rejects a constraint of the full
/// one. The answer streams into the channel, with the provider's own members of each chunk read alongside the
/// format's. Every failure becomes the provider's error.
package struct ChatCompletionsExecutor<Provider: ChatCompletionsProvider>: Sendable {
    private let provider: Provider
    private let session: URLSession
    private let idleTimeout: Duration?
    private let retryDelay: Duration

    /// Creates an executor.
    ///
    /// - Parameters:
    ///   - provider: The service the requests go to.
    ///   - session: The URL session that sends them.
    ///   - idleTimeout: How long to wait for the next data, or `nil` for the session's own timeout.
    ///   - retryDelay: The shortest wait before the one retry of a briefly unavailable gateway or host.
    package init(_ provider: Provider, session: URLSession = .shared, idleTimeout: Duration? = nil, retryDelay: Duration = .seconds(1)) {
        self.provider = provider
        self.session = session
        self.idleTimeout = idleTimeout
        self.retryDelay = retryDelay
    }

    /// Sends one request and streams its answer.
    ///
    /// - Parameters:
    ///   - request: The transcript, tools, schema and options to send.
    ///   - channel: Where the answer's events go.
    /// - Returns: The answer's response text, which the model's executor checks against the request's schema, or
    ///   empty text when the answer ends in tool calls.
    /// - Throws: `LanguageModelError` for failures Foundation Models has a case for, the provider's errors for the
    ///   rest, a failed connection's error as `URLError` maps it, and `CancellationError` when the task is cancelled.
    package func respond(
        to request: LanguageModelExecutorGenerationRequest,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws -> DetailedLanguageModelAnswer {
        var log = OperationLog(request: request.id, logger: PackageLogger(category: provider.name))
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
        let completion = try ChatCompletionRequest(request, provider: provider)
        logSending(completion.body, log: log)
        for adjustment in completion.adjustments {
            log.report(adjustment, model: provider.modelID, provider: provider.name)
        }
        do {
            let headers = try await provider.headers(for: request)
            let url = try provider.baseURL.appending(path: Self.path)
            let (bytes, response) = try await open(completion, url: url, headers: headers, log: log)
            var answer = AnswerStream(
                channel: channel, provider: provider, response: response, imageEntries: completion.imageEntries,
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
    /// - Returns: The stream, and the response whose headers came with it.
    private func open(
        _ completion: ChatCompletionRequest,
        url: URL,
        headers: [String: String],
        log: OperationLog
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse?) {
        let http = ProviderHTTP(session: session, retryStatuses: Self.retryStatuses, retryDelay: retryDelay)
        var urlRequest = ProviderHTTP.request(
            url: url, method: HTTPMethod.post, body: completion.body.data, accept: MediaType.eventStream, authHeaders: [:],
            headers: headers, idleTimeout: idleTimeout)
        var portableSchemaBody = completion.portableSchemaBody
        while true {
            let rejected: ProviderHTTP.Failure
            do {
                return try await http.stream(urlRequest) { log.retrying(status: $0, after: $1) }
            } catch let failure as ProviderHTTP.Failure {
                rejected = failure
            }
            if let body = portableSchemaBody,
                APIFormat.rejectsSchemaConstraint(status: rejected.status, message: String(decoding: rejected.body, as: UTF8.self))
            {
                log.retryingWithPortableSchema(host: nil)
                urlRequest.httpBody = body.data
                portableSchemaBody = nil
                continue
            }
            throw provider.error(for: Failure(.response(rejected), provider: provider.name, imageEntries: completion.imageEntries))
        }
    }

    /// Logs at `debug` what the request sends: the model and the names of the options, never the transcript.
    private func logSending(_ body: JSONValue, log: OperationLog) {
        guard let logger = PackageLogger(category: provider.name)(.debug) else { return }
        let options = if case .object(let body) = body { body.members.map(\.key) } else { [String]() }
        let sent = options.filter { !Self.nonOptions.contains($0) }.joined(separator: ", ")
        logger.debug("\(log.label, privacy: .public) to \(provider.modelID, privacy: .public); sends \(sent, privacy: .public)")
    }

    /// Logs at `debug` which model and host answered, why the answer ended, the time to its first token and the
    /// request's whole time.
    private func logFinished(_ answer: AnswerStream<Provider>, log: OperationLog) {
        guard let logger = PackageLogger(category: provider.name)(.debug) else { return }
        let host = provider.facts(of: answer.stream).host
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

    /// The statuses of a briefly unavailable gateway or host, which are retried once.
    private static var retryStatuses: Set<Int> { [502, 503, 504, 529] }

    /// The body's members that aren't options: the model and the transcript.
    private static var nonOptions: Set<String> { ["model", "messages", "stream"] }
}
