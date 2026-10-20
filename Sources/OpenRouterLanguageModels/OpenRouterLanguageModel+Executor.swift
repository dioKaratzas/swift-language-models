import Foundation
public import FoundationModels
import LanguageModels

extension OpenRouterLanguageModel {
    /// Sends a model's requests to OpenRouter and streams each answer into Foundation Models.
    ///
    /// Foundation Models creates the executor and calls it for each answer. It keeps no state between answers.
    public struct Executor: LanguageModelExecutor {
        /// Where the executor sends requests, how it names the app and how long it waits. It holds no secrets.
        public struct Configuration: Sendable, Hashable {
            let baseURL: URL?
            let appName: String?
            let appURL: URL?
            let appCategories: [OpenRouterAppCategory]
            let hidesApp: Bool
            let idleTimeout: Duration?
            /// The wait before the one retry of a gateway failure.
            var retryDelay: Duration = .seconds(1)

            init(
                baseURL: URL?,
                appName: String?,
                appURL: URL?,
                appCategories: [OpenRouterAppCategory] = [],
                hidesApp: Bool = false,
                idleTimeout: Duration?,
                retryDelay: Duration = .seconds(1)
            ) {
                self.baseURL = baseURL
                self.appName = appName
                self.appURL = appURL
                self.appCategories = appCategories
                self.hidesApp = hidesApp
                self.idleTimeout = idleTimeout
                self.retryDelay = retryDelay
            }

            /// The same configuration for a model with another effort type.
            init(_ other: OpenRouterLanguageModel<some ModelEffort>.Executor.Configuration) {
                self.init(
                    baseURL: other.baseURL,
                    appName: other.appName,
                    appURL: other.appURL,
                    appCategories: other.appCategories,
                    hidesApp: other.hidesApp,
                    idleTimeout: other.idleTimeout,
                    retryDelay: other.retryDelay
                )
            }
        }

        private let configuration: Configuration

        /// Creates an executor.
        ///
        /// - Parameter configuration: Where to send requests and how to name the app.
        public init(configuration: Configuration) {
            self.configuration = configuration
        }

        /// Sends one request and streams its answer.
        ///
        /// A failed request is retried once, only before any data arrives, when OpenRouter or the host is briefly
        /// unavailable.
        ///
        /// - Parameters:
        ///   - request: The transcript, tools, schema and options to send.
        ///   - model: The model to answer with.
        ///   - channel: Where the answer's events go.
        /// - Throws: `LanguageModelError` for failures Foundation Models has a case for, `OpenRouterError` for the
        ///   rest, and `CancellationError` when the task is cancelled.
        public func respond(
            to request: LanguageModelExecutorGenerationRequest,
            model: OpenRouterLanguageModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
            let completionRequest = try ChatCompletionRequest(request, model: model)
            var answer = AnswerStream(channel: channel, contextSize: model.sharedDetails.contextSize)
            var isComplete = false
            do {
                let (bytes, response) = try await stream(completionRequest, model: model)
                answer.receive(response)
                for try await line in ByteLines(bytes) {
                    try Task.checkCancellation()
                    guard case .data(let payload) = ServerSentEventLine(line), !payload.isEmpty else { continue }
                    if payload == "[DONE]" {
                        isComplete = true
                        break
                    }
                    try await answer.receive(try Self.chunk(payload))
                }
            } catch let error as URLError {
                throw Self.error(for: error)
            }
            try Task.checkCancellation()
            try await answer.finish(isComplete: isComplete)
        }

        /// Opens the response stream, retrying once on a gateway failure.
        ///
        /// - Returns: The stream, and the response whose headers came with it.
        private func stream(_ completionRequest: ChatCompletionRequest, model: OpenRouterLanguageModel) async throws
            -> (URLSession.AsyncBytes, HTTPURLResponse?)
        {
            let request = try await urlRequest(completionRequest, apiKey: model.apiKey())
            var hasRetried = false
            while true {
                let (bytes, response) = try await model.session.bytes(for: request, delegate: SameHostRedirects())
                let http = response as? HTTPURLResponse
                // A response that isn't HTTP has no status; 0 isn't a status OpenRouter sends.
                let status = http?.statusCode ?? 0
                if (200..<300).contains(status) { return (bytes, http) }
                if !hasRetried, API.gatewayStatuses.contains(status) {
                    bytes.task.cancel()
                    hasRetried = true
                    try await Task.sleep(for: configuration.retryDelay)
                    continue
                }
                let data = try await Self.prefix(of: bytes)
                throw OpenRouterFailure(
                    status: status,
                    body: try? JSONDecoder().decode(OpenRouterErrorResponse.Envelope.self, from: data).error,
                    retryAfter: Duration(retryAfter: http?.value(forHTTPHeaderField: "Retry-After"))
                        ?? Duration(rateLimitReset: http?.value(forHTTPHeaderField: "X-RateLimit-Reset"))
                )
                .error(contextSize: model.sharedDetails.contextSize)
            }
        }

        private func urlRequest(_ completionRequest: ChatCompletionRequest, apiKey: String) throws -> URLRequest {
            guard let base = configuration.baseURL ?? API.defaultBaseURL else {
                throw OpenRouterError(message: "The base URL isn't valid.", code: .invalidRequest)
            }
            var request = URLRequest(url: base.appending(path: "chat/completions"))
            request.httpMethod = "POST"
            request.httpBody = completionRequest.body.data
            for (name, value) in completionRequest.headers {
                request.setValue(value, forHTTPHeaderField: name)
            }
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue(configuration.appURL?.absoluteString, forHTTPHeaderField: "HTTP-Referer")
            request.setValue(configuration.appName, forHTTPHeaderField: "X-OpenRouter-Title")
            let categories = configuration.appCategories.prefix(API.appCategoryLimit).map(\.rawValue)
            request.setValue(categories.isEmpty ? nil : categories.joined(separator: ","), forHTTPHeaderField: "X-OpenRouter-Categories")
            request.setValue(configuration.hidesApp ? "hidden" : nil, forHTTPHeaderField: "X-OpenRouter-App-Visibility")
            if let timeout = configuration.idleTimeout {
                request.timeoutInterval = timeout / .seconds(1)
            }
            return request
        }

        /// The error to throw for a failed connection: cancellation as `CancellationError`, a timeout as
        /// `LanguageModelError.timeout`, and anything else as `OpenRouterError`.
        private static func error(for error: URLError) -> any Error {
            switch error.code {
            case .cancelled: CancellationError()
            case .timedOut: LanguageModelError.timeout(.init(debugDescription: error.localizedDescription))
            default: OpenRouterError(message: error.localizedDescription, code: .connectionFailed)
            }
        }

        private static func chunk(_ payload: String) throws -> ChatCompletionChunk {
            do {
                return try ChatCompletionChunk.decoded(from: Data(payload.utf8))
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

/// Facts about OpenRouter's API that the executor relies on. They live outside the executor because a generic type
/// can't store static values.
private enum API {
    /// Where OpenRouter's API lives. `URL(string:)` makes it optional, although it never fails.
    static let defaultBaseURL = URL(string: "https://openrouter.ai/api/v1/")

    /// The statuses of a briefly unavailable gateway or host, which are retried once.
    static let gatewayStatuses: Set<Int> = [502, 503, 504, 529]

    /// The most bytes of a failed response's body to read.
    static let errorBodyLimit = 1 << 20

    /// The most app categories OpenRouter takes on one request.
    static let appCategoryLimit = 2
}
