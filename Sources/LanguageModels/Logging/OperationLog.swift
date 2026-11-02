package import Foundation
import os

/// The timing, retry and failure messages of one operation a provider runs, such as a request or a call for a model's
/// info, under a label that names it, such as `Request 1A2B3C4D`.
///
/// It logs retries at `info`, a cancellation at `debug` and any other failure at `error`, with the error's message
/// kept private, since it may quote the request.
package struct OperationLog {
    /// What names the operation in each message.
    package let label: String
    private let logger: PackageLogger
    private let start = ContinuousClock.now
    private var firstToken: ContinuousClock.Instant?

    /// Starts the log of an operation, and its timing.
    ///
    /// - Parameters:
    ///   - label: What names the operation, such as `GET models`.
    ///   - logger: The provider's log category.
    package init(_ label: String, logger: PackageLogger) {
        self.label = label
        self.logger = logger
    }

    /// Starts the log of a generation request, named by the start of the id Foundation Models gave it, as the core's
    /// own messages about the request name it.
    package init(request id: UUID, logger: PackageLogger) {
        self.init("Request \(Self.requestName(id))", logger: logger)
    }

    /// The start of a request's id, which names it in the log.
    static func requestName(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }

    /// The milliseconds since the operation started.
    package var elapsedMilliseconds: Int {
        Self.milliseconds(ContinuousClock.now - start)
    }

    /// When the first token arrived after the start, such as `120 ms`, or `never`.
    package var firstTokenDelay: String {
        firstToken.map { "\(Self.milliseconds($0 - start)) ms" } ?? "never"
    }

    /// Notes when the answer's first token arrived, once.
    package mutating func receivedToken() {
        firstToken = firstToken ?? ContinuousClock.now
    }

    /// Logs the retry of a gateway's or host's brief failure.
    package func retrying(status: Int, after delay: Duration) {
        logger(.info)?.info(
            """
            \(label, privacy: .public) got HTTP \(status) from a briefly unavailable gateway or host; retrying once \
            after \(Self.milliseconds(delay)) ms.
            """
        )
    }

    /// Logs what a request leaves out or changes from what the app asked for, at `info` with the keys of metadata left
    /// out kept private, and shows it as a runtime warning in a debug build.
    ///
    /// - Parameters:
    ///   - adjustment: The change.
    ///   - model: The id of the model the request names first.
    ///   - provider: The provider's name, such as `OpenRouter`.
    package func report(_ adjustment: APIFormat.Adjustment, model: String, provider: String) {
        if let logger = logger(.info) {
            let message = adjustment.message(model: model, provider: provider)
            if case .droppedMetadata(let keys) = adjustment {
                let keys = keys.joined(separator: ", ")
                logger.info("\(label, privacy: .public): \(message, privacy: .public) Keys: \(keys, privacy: .private)")
            } else {
                logger.info("\(label, privacy: .public): \(message, privacy: .public)")
            }
        }
        runtimeWarning(adjustment.warning(model: model, provider: provider))
    }

    /// Logs the retry of a request whose host rejected a constraint of its response schema.
    ///
    /// - Parameter host: The company whose servers rejected it, when the provider names one.
    package func retryingWithPortableSchema(host: String?) {
        logger(.info)?.info(
            """
            \(label, privacy: .public): \(host ?? "the host", privacy: .public) rejected a constraint of the response \
            schema; retrying with the portable schema.
            """
        )
    }

    /// Logs a cancellation at `debug`, and any other failure at `error`, with the error it became.
    package func failed(_ error: any Error) {
        if error is CancellationError {
            logger(.debug)?.debug("\(label, privacy: .public) was cancelled after \(elapsedMilliseconds) ms.")
            return
        }
        guard let logger = logger(.error) else { return }
        let failure = LoggedError(error)
        let origin = failure.origin.isEmpty ? "" : " (\(failure.origin))"
        logger.error(
            """
            \(label, privacy: .public) failed after \(elapsedMilliseconds) ms with \(failure.kind, privacy: .public)\
            \(origin, privacy: .public).
            """
        )
    }

    /// A duration in whole milliseconds.
    private static func milliseconds(_ duration: Duration) -> Int {
        Int(duration / .milliseconds(1))
    }
}
