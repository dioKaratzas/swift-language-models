import Foundation
import LanguageModels
import os

/// The messages one call to OpenRouter's API besides chat completions logs, such as for a model's providers.
///
/// Calls log at `debug` how they end and whether the cache answered, at `info` their retries, and at `error` how they
/// fail. They log the path, but never the key.
struct CallLog {
    private let call: String
    private let start = ContinuousClock.now
    private var status: Int?

    /// Starts the log of a call, and its timing.
    ///
    /// - Parameter path: The path under the base URL, such as `models/anthropic/claude-haiku-5.5/endpoints`.
    init(path: String) {
        call = "GET \(path)"
    }

    mutating func received(status: Int) {
        self.status = status
    }

    func answeredFromCache() {
        PackageLogger.openRouter(.debug)?.debug("\(call, privacy: .public) answered from the cache.")
    }

    func retrying(after delay: Duration) {
        PackageLogger.openRouter(.info)?.info(
            """
            \(call, privacy: .public) got HTTP \(status ?? 0) from a briefly unavailable gateway; retrying once after \
            \(Self.milliseconds(delay)) ms.
            """
        )
    }

    func finished() {
        PackageLogger.openRouter(.debug)?.debug(
            "\(call, privacy: .public) answered with HTTP \(status ?? 0) in \(elapsedMilliseconds) ms.")
    }

    /// Logs a cancelled call at `debug`, and any other failure at `error`, with the error it became.
    func failed(_ error: any Error) {
        if error is CancellationError {
            PackageLogger.openRouter(.debug)?.debug("\(call, privacy: .public) was cancelled after \(elapsedMilliseconds) ms.")
            return
        }
        guard let logger = PackageLogger.openRouter(.error) else { return }
        let failure = LoggedError(error)
        let origin = failure.origin.isEmpty ? "" : " (\(failure.origin))"
        logger.error(
            """
            \(call, privacy: .public) failed after \(elapsedMilliseconds) ms with \(failure.kind, privacy: .public)\
            \(origin, privacy: .public): \(failure.message, privacy: .private)
            """
        )
    }

    private var elapsedMilliseconds: Int {
        Self.milliseconds(ContinuousClock.now - start)
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        Int(duration / .milliseconds(1))
    }
}
