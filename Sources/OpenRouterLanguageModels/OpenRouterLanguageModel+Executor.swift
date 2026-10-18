public import Foundation
public import FoundationModels
import LanguageModels

extension OpenRouterLanguageModel {
    /// Sends a model's requests to OpenRouter and streams each answer into Foundation Models.
    ///
    /// Foundation Models creates the executor and calls it for each answer. It keeps no state between answers.
    public struct Executor: LanguageModelExecutor {
        /// Where the executor sends requests and how it names the app. It holds no secrets.
        public struct Configuration: Sendable, Hashable {
            let baseURL: URL?
            let appName: String?
            let appURL: URL?
            let responseStartTimeout: Duration?
            /// The wait before the one retry of a gateway failure.
            var retryDelay: Duration = .seconds(1)
        }

        private static var gatewayStatuses: Set<Int> { [502, 503, 504, 529] }
        private static var defaultBaseURL: String { "https://openrouter.ai/api/v1/" }
        /// The most bytes of a failed response's body to read.
        private static var errorBodyLimit: Int { 1 << 20 }

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
            let body = try ChatCompletionRequest(request, model: model).body.data
            var answer = AnswerStream(channel: channel, contextSize: model.details.contextSize)
            var isComplete = false
            do {
                let bytes = try await stream(body, model: model)
                for try await line in ByteLines(bytes) {
                    try Task.checkCancellation()
                    guard case .data(let payload) = ServerSentEvent(line: line[...]), !payload.isEmpty else { continue }
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
        private func stream(_ body: Data, model: OpenRouterLanguageModel) async throws -> URLSession.AsyncBytes {
            let request = try await urlRequest(body, apiKey: model.apiKey())
            var hasRetried = false
            while true {
                let (bytes, response) = try await model.session.bytes(for: request, delegate: SameHostRedirects())
                let http = response as? HTTPURLResponse
                // A response that isn't HTTP has no status; 0 isn't a status OpenRouter sends.
                let status = http?.statusCode ?? 0
                if (200..<300).contains(status) { return bytes }
                if !hasRetried, Self.gatewayStatuses.contains(status) {
                    bytes.task.cancel()
                    hasRetried = true
                    try await Task.sleep(for: configuration.retryDelay)
                    continue
                }
                let data = try await Self.prefix(of: bytes)
                throw OpenRouterFailure(
                    status: status,
                    body: try? JSONDecoder().decode(OpenRouterErrorBody.Envelope.self, from: data).error,
                    retryAfter: Duration(retryAfter: http?.value(forHTTPHeaderField: "Retry-After"))
                        ?? Duration(rateLimitReset: http?.value(forHTTPHeaderField: "X-RateLimit-Reset"))
                )
                .error(contextSize: model.details.contextSize)
            }
        }

        private func urlRequest(_ body: Data, apiKey: String) throws -> URLRequest {
            guard let base = configuration.baseURL ?? URL(string: Self.defaultBaseURL) else {
                throw OpenRouterError(message: "The base URL isn't valid.", code: .invalidRequest)
            }
            var request = URLRequest(url: base.appending(path: "chat/completions"))
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue(configuration.appURL?.absoluteString, forHTTPHeaderField: "HTTP-Referer")
            request.setValue(configuration.appName, forHTTPHeaderField: "X-OpenRouter-Title")
            if let timeout = configuration.responseStartTimeout {
                request.timeoutInterval = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
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
                if data.count >= errorBodyLimit { break }
            }
            return data
        }
    }
}
