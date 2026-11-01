import Foundation
public import FoundationModels
import LanguageModels

extension OpenRouterLanguageModel {
    /// Sends a model's requests to OpenRouter and streams each answer into Foundation Models.
    ///
    /// The model's executor, a `DetailedLanguageModelExecutor` of this request executor, creates it and calls it for
    /// each answer. It keeps no state between answers.
    public struct RequestExecutor: DetailedLanguageModelRequestExecutor {
        /// The model the request executor sends requests for.
        public typealias Model = OpenRouterLanguageModel

        /// Where the request executor sends requests, how it names the app and how long it waits. It holds no
        /// secrets.
        public struct Configuration: Sendable, Hashable {
            let baseURL: URL?
            let app: OpenRouterApp
            let idleTimeout: Duration?
            /// The wait before the one retry of a gateway failure.
            var retryDelay: Duration = .seconds(1)

            init(baseURL: URL?, app: OpenRouterApp = OpenRouterApp(), idleTimeout: Duration?, retryDelay: Duration = .seconds(1)) {
                self.baseURL = baseURL
                self.app = app
                self.idleTimeout = idleTimeout
                self.retryDelay = retryDelay
            }

            /// The same configuration for a model with another effort type.
            init(_ other: OpenRouterLanguageModel<some ModelEffort>.RequestExecutor.Configuration) {
                self.init(baseURL: other.baseURL, app: other.app, idleTimeout: other.idleTimeout, retryDelay: other.retryDelay)
            }
        }

        private let configuration: Configuration

        /// Creates a request executor.
        ///
        /// - Parameter configuration: Where to send requests and how to name the app.
        public init(configuration: Configuration) {
            self.configuration = configuration
        }

        /// Sends one request and streams its answer.
        ///
        /// A failed request is retried once, only before any data arrives, when OpenRouter or the host is briefly
        /// unavailable. A request whose schema has a constraint the host rejects is sent once more with the portable
        /// schema, which carries its constraints in descriptions.
        ///
        /// - Parameters:
        ///   - request: The transcript, tools, schema and options to send.
        ///   - model: The model to answer with.
        ///   - channel: Where the answer's events go.
        /// - Returns: The answer's response text, which the model's executor checks against the request's schema.
        /// - Throws: `LanguageModelError` for failures Foundation Models has a case for, `OpenRouterError` for the
        ///   rest, and `CancellationError` when the task is cancelled. An error that the model's authentication
        ///   throws passes through as it is, unless it's a `URLError`, which maps as a failed connection's does.
        public func execute(
            _ request: LanguageModelExecutorGenerationRequest,
            model: OpenRouterLanguageModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws -> DetailedLanguageModelAnswer {
            var log = RequestLog(id: request.id)
            do {
                return try await respond(to: request, model: model, streamingInto: channel, log: &log)
            } catch {
                log.failed(error)
                throw error
            }
        }

        /// Sends one request, streams its answer and returns its response text, logging what it sends, its retries and
        /// how it ends.
        private func respond(
            to request: LanguageModelExecutorGenerationRequest,
            model: OpenRouterLanguageModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel,
            log: inout RequestLog
        ) async throws -> DetailedLanguageModelAnswer {
            let details = model.sharedDetails
            let completionRequest = try ChatCompletionRequest(request, model: model, details: details)
            log.sending(completionRequest)
            do {
                let (bytes, response) = try await stream(completionRequest, model: model, contextSize: details.contextSize, log: log)
                var answer = AnswerStream(channel: channel, contextSize: details.contextSize, responseCache: ResponseCacheStatus(response))
                var isComplete = false
                for try await line in ByteLines(bytes) {
                    try Task.checkCancellation()
                    guard case .data(let payload) = ServerSentEventLine(line), !payload.isEmpty else { continue }
                    if payload == "[DONE]" {
                        isComplete = true
                        break
                    }
                    try await answer.receive(try Self.chunk(payload))
                    if answer.hasOutput { log.receivedToken() }
                }
                try Task.checkCancellation()
                try await answer.finish(isComplete: isComplete)
                log.finished(answer.facts)
                return DetailedLanguageModelAnswer(responseText: answer.responseText)
            } catch let error as URLError {
                throw error.thrownError
            }
        }

        /// Opens the response stream, retrying once on a gateway failure, and once with the portable schema when the
        /// host rejects a constraint of the full one. An oversized prompt's error reports `contextSize`, the smallest
        /// context size of the models, when OpenRouter's message doesn't say.
        ///
        /// - Returns: The stream, and the response whose headers came with it.
        private func stream(
            _ completionRequest: ChatCompletionRequest,
            model: OpenRouterLanguageModel,
            contextSize: Int?,
            log: RequestLog
        ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse?) {
            var request = try await urlRequest(completionRequest, authHeaders: model.auth.requestHeaders())
            var hasRetried = false
            var portableSchemaBody = completionRequest.portableSchemaBody
            while true {
                let (bytes, response) = try await model.session.bytes(for: request, delegate: SameHostRedirects())
                let http = response as? HTTPURLResponse
                // A response that isn't HTTP has no status; 0 isn't a status OpenRouter sends.
                let status = http?.statusCode ?? 0
                if (200..<300).contains(status) { return (bytes, http) }
                if !hasRetried, API.gatewayStatuses.contains(status) {
                    bytes.task.cancel()
                    hasRetried = true
                    log.retrying(status: status, after: configuration.retryDelay)
                    try await Task.sleep(for: configuration.retryDelay)
                    continue
                }
                let data = try await Self.prefix(of: bytes)
                let failure = OpenRouterFailure(
                    status: status,
                    body: try? API.decoder.decode(OpenRouterErrorResponse.Envelope.self, from: data).error,
                    retryAfter: Duration(retryAfter: http?.value(forHTTPHeaderField: "Retry-After"))
                        ?? Duration(rateLimitReset: http?.value(forHTTPHeaderField: "X-RateLimit-Reset"))
                )
                if let body = portableSchemaBody, failure.rejectsSchemaConstraint {
                    log.retryingWithPortableSchema(after: failure)
                    request.httpBody = body.data
                    portableSchemaBody = nil
                    continue
                }
                throw failure.error(contextSize: contextSize)
            }
        }

        /// The request for a chat completion: its body, the authentication's headers, then the package's own, which
        /// take precedence over a header of the same name.
        private func urlRequest(_ completionRequest: ChatCompletionRequest, authHeaders: [String: String]) throws -> URLRequest {
            guard let base = configuration.baseURL ?? API.defaultBaseURL else {
                throw OpenRouterError(message: "The base URL isn't valid.", code: .invalidRequest)
            }
            var request = URLRequest(url: base.appending(path: "chat/completions"))
            request.httpMethod = "POST"
            request.httpBody = completionRequest.body.data
            for (name, value) in authHeaders {
                request.setValue(value, forHTTPHeaderField: name)
            }
            for (name, value) in completionRequest.headers {
                request.setValue(value, forHTTPHeaderField: name)
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue(UserAgent.current, forHTTPHeaderField: "User-Agent")
            let app = configuration.app
            request.setValue(app.url?.absoluteString, forHTTPHeaderField: "HTTP-Referer")
            request.setValue(app.name, forHTTPHeaderField: "X-OpenRouter-Title")
            let categories = app.categories.prefix(API.appCategoryLimit).map(\.rawValue)
            request.setValue(categories.isEmpty ? nil : categories.joined(separator: ","), forHTTPHeaderField: "X-OpenRouter-Categories")
            request.setValue(app.isHidden ? "hidden" : nil, forHTTPHeaderField: "X-OpenRouter-App-Visibility")
            if let timeout = configuration.idleTimeout {
                request.timeoutInterval = timeout / .seconds(1)
            }
            return request
        }

        private static func chunk(_ payload: String) throws -> ChatCompletionChunk {
            do {
                return try API.decoder.decode(ChatCompletionChunk.self, from: Data(payload.utf8))
            } catch {
                throw OpenRouterError(message: "OpenRouter sent an event that couldn't be read: \(error)", code: .invalidResponse)
            }
        }

        /// The start of a failed response's body, which holds its error.
        private static func prefix(of bytes: URLSession.AsyncBytes) async throws -> Data {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                if data.count >= API.errorBodyLimit { break }
            }
            return data
        }
    }
}
