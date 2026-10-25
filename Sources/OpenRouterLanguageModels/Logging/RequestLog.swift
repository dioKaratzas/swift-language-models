import Foundation
import LanguageModels
import os

/// The messages one request logs. Each names the request by the start of its id, so the messages of requests sent at
/// once can be told apart.
///
/// Requests log at `debug` what they send and how they end, at `info` what they leave out or change and their retries,
/// and at `error` how they fail. They never log the API key, the transcript, tool calls or the answer.
struct RequestLog {
    private let id: String
    private let start = ContinuousClock.now
    private var firstToken: ContinuousClock.Instant?

    /// The body's members that aren't options: the models and the transcript.
    private static let nonOptions: Set<String> = ["model", "models", "messages", "stream"]

    /// Starts the log of a request, and its timing.
    ///
    /// - Parameter id: The id Foundation Models gave the request.
    init(id: UUID) {
        self.id = String(id.uuidString.prefix(8))
    }

    /// Logs what the request sends: the model, its fallbacks and the names of the options; then what it leaves out or
    /// changes from what the app asked for, which a debug build also shows as a runtime warning.
    func sending(_ request: ChatCompletionRequest) {
        let model = request.body["model"]?.stringValue ?? ""
        if let logger = PackageLogger.openRouter(.debug) {
            let fallbacks = if case .array(let ids)? = request.body["models"] { ids.compactMap(\.stringValue) } else { [String]() }
            let options = if case .object(let body) = request.body { body.members.map(\.key) } else { [String]() }
            logger.debug(
                """
                Request \(id, privacy: .public) to \(model, privacy: .public), \
                fallbacks: \(fallbacks.isEmpty ? "none" : fallbacks.joined(separator: ", "), privacy: .public); \
                sends \(options.filter { !Self.nonOptions.contains($0) }.joined(separator: ", "), privacy: .public)
                """
            )
        }
        for adjustment in request.adjustments {
            report(adjustment, model: model)
            runtimeWarning(adjustment.warning(model: model))
        }
    }

    /// Logs what the request leaves out or changes from what the app asked for, with the keys of metadata left out kept
    /// private.
    private func report(_ adjustment: RequestAdjustment, model: String) {
        guard let logger = PackageLogger.openRouter(.info) else { return }
        let message = adjustment.message(model: model)
        if case .droppedMetadata(let keys) = adjustment {
            let keys = keys.joined(separator: ", ")
            logger.info("Request \(id, privacy: .public): \(message, privacy: .public) Keys: \(keys, privacy: .private)")
        } else {
            logger.info("Request \(id, privacy: .public): \(message, privacy: .public)")
        }
    }

    /// Logs the retry of a gateway failure.
    ///
    /// - Parameters:
    ///   - status: The failure's HTTP status.
    ///   - delay: The wait before the retry.
    func retrying(status: Int, after delay: Duration) {
        PackageLogger.openRouter(.info)?.info(
            """
            Request \(id, privacy: .public) got HTTP \(status) from a briefly unavailable gateway or host; \
            retrying once after \(Self.milliseconds(delay)) ms.
            """
        )
    }

    /// Logs the retry of a request whose host rejected a constraint of its response schema.
    ///
    /// - Parameter failure: The host's rejection, whose message may quote the schema.
    func retryingWithPortableSchema(after failure: OpenRouterFailure) {
        PackageLogger.openRouter(.info)?.info(
            """
            Request \(id, privacy: .public): \(failure.providerName?.rawValue ?? "the host", privacy: .public) rejected a \
            constraint of the response schema (\(failure.body.bestMessage, privacy: .private)); retrying with the \
            portable schema.
            """
        )
    }

    /// Notes when the answer's first token arrived, once: the first text, reasoning or tool call.
    mutating func receivedToken() {
        firstToken = firstToken ?? ContinuousClock.now
    }

    /// Logs which model and host answered, why the answer ended, whether the response cache served it, the time to
    /// its first token and the request's whole time.
    func finished(_ answer: AnswerFacts) {
        guard let logger = PackageLogger.openRouter(.debug) else { return }
        let firstToken = firstToken.map { "\(Self.milliseconds($0 - start)) ms" } ?? "never"
        let cache = answer.responseCache.map { $0.isHit ? "hit" : "miss" } ?? "off"
        logger.debug(
            """
            Request \(id, privacy: .public) answered by \(answer.model ?? "an unnamed model", privacy: .public) on \
            \(answer.provider?.rawValue ?? "an unnamed host", privacy: .public) in \(elapsedMilliseconds) ms, \
            first token after \(firstToken, privacy: .public); finish reason \
            \(answer.finishReason?.rawValue ?? "none", privacy: .public), response cache \(cache, privacy: .public)
            """
        )
    }

    /// Logs a cancelled request at `debug`, and any other failure at `error`, with the error it became.
    func failed(_ error: any Error) {
        if error is CancellationError {
            PackageLogger.openRouter(.debug)?.debug(
                "Request \(id, privacy: .public) was cancelled after \(elapsedMilliseconds) ms.")
            return
        }
        guard let logger = PackageLogger.openRouter(.error) else { return }
        let failure = LoggedError(error)
        let origin = failure.origin.isEmpty ? "" : " (\(failure.origin))"
        logger.error(
            """
            Request \(id, privacy: .public) failed after \(elapsedMilliseconds) ms with \(failure.kind, privacy: .public)\
            \(origin, privacy: .public): \(failure.message, privacy: .private)
            """
        )
    }

    /// The milliseconds since the request started.
    private var elapsedMilliseconds: Int {
        Self.milliseconds(ContinuousClock.now - start)
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        Int(duration / .milliseconds(1))
    }
}
