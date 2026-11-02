package import LanguageModels
import os

extension OperationLog {
    /// Logs what a request leaves out or changes from what the app asked for, at `info` with the keys of metadata left
    /// out kept private, and shows it as a runtime warning in a debug build.
    ///
    /// - Parameters:
    ///   - adjustment: The change.
    ///   - model: The id of the model the request names first.
    ///   - provider: The provider's name, such as `OpenRouter`.
    package func report(_ adjustment: RequestAdjustment, model: String, provider: String) {
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
}
