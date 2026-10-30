import Foundation
import FoundationModels

extension URLError {
    /// The error to throw for a failed connection: cancellation as `CancellationError`, a timeout as
    /// `LanguageModelError.timeout`, and anything else as `OpenRouterError`.
    var thrownError: any Error {
        switch code {
        case .cancelled: CancellationError()
        case .timedOut: LanguageModelError.timeout(.init(debugDescription: localizedDescription))
        default: OpenRouterError(message: localizedDescription, code: .connectionFailed)
        }
    }
}
