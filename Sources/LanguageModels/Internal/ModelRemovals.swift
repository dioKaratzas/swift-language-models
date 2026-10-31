package import Foundation
import os

/// The models a provider stopped listing, which its catalog keeps as deprecated members, each with the day it left.
///
/// The model catalog generator writes one for each provider module, as a static member such as
/// `ModelRemovals.vendor`, which the module's details read for their ``ModelDetails/removalDate``.
package struct ModelRemovals: Sendable {
    /// Midnight UTC at the start of the day the provider stopped listing each model, by id.
    package let dates: [String: Date]

    /// Creates the removals of a provider's catalog.
    ///
    /// - Parameter dates: Midnight UTC at the start of the day the provider stopped listing each model, by id.
    package init(_ dates: [String: Date]) {
        self.dates = dates
    }

    /// The day the provider stopped listing a model.
    ///
    /// - Parameter id: The model's id, as the provider's API spells it.
    /// - Returns: The day, or `nil` while the provider lists the model.
    package func removalDate(of id: String) -> Date? {
        dates[id]
    }
}

/// A model a request may reach, as its model or a fallback, that its provider stopped listing, so the request may
/// fail, to report before the request is sent.
package struct RemovedModelReport: Equatable, Sendable {
    /// The model's id.
    package let id: String
    /// Midnight UTC at the start of the day the provider stopped listing the model.
    package let removedOn: Date

    /// The log message and runtime warning, which name the model and the day.
    package var message: String {
        let day = removedOn.formatted(.iso8601.year().month().day())
        return "The request names \(id), which its provider stopped listing on \(day), so it may fail. Choose another model."
    }

    /// Logs the model at the error level, and shows a runtime warning in a debug build.
    ///
    /// - Parameter request: The start of the request's id, which names the request in the log.
    func report(request: String) {
        PackageLogger.languageModels(.error)?.error("Request \(request, privacy: .public): \(message, privacy: .public)")
        runtimeWarning(message)
    }
}

extension DetailedLanguageModelBase {
    /// The model and fallbacks that their provider stopped listing, in the order the provider tries them.
    package var removedModels: [RemovedModelReport] {
        let reachable: [any ModelDetails] = [details] + fallbacks
        return reachable.compactMap { details in
            details.removalDate.map { RemovedModelReport(id: String(describing: details.id), removedOn: $0) }
        }
    }
}

extension PackageLogger {
    /// The category of what the core logs for every provider module.
    static let languageModels = PackageLogger(category: "LanguageModels")
}
