package import Foundation
package import FoundationModels

extension LanguageModelError {
    /// A failure a provider reported that Foundation Models has a case for.
    package enum ProviderFailure {
        /// The prompt is longer than the model's context, with the sizes when known; 0 stands for an unknown one.
        case contextSizeExceeded(contextSize: Int, tokenCount: Int)
        case rateLimited(resetDate: Date?)
        case guardrailViolation
        case refusal
        case timeout
        /// Content of these entries that the host can't use, such as an image in a format it doesn't take.
        case unsupportedContent([Transcript.Entry])
    }

    /// The error a provider's failure becomes.
    ///
    /// - Parameters:
    ///   - failure: The Foundation Models case the failure stands for.
    ///   - message: What went wrong, as the provider said it.
    ///   - metadata: The failure's facts, under the shared keys such as `status`, and the provider's own.
    package init(_ failure: ProviderFailure, message: String, metadata: [String: any Sendable]) {
        switch failure {
        case .contextSizeExceeded(let contextSize, let tokenCount):
            var exceeded = ContextSizeExceeded(contextSize: contextSize, tokenCount: tokenCount, debugDescription: message)
            // Foundation Models 2.1.14, in Xcode 27.2, drops the initializer's `metadata` argument, so it's set afterwards.
            exceeded.metadata = metadata
            self = .contextSizeExceeded(exceeded)
        case .rateLimited(let resetDate):
            self = .rateLimited(.init(resetDate: resetDate, debugDescription: message, metadata: metadata))
        case .guardrailViolation:
            self = .guardrailViolation(.init(debugDescription: message, metadata: metadata))
        case .refusal:
            self = .refusal(.init(explanation: message, debugDescription: message, metadata: metadata))
        case .timeout:
            self = .timeout(.init(debugDescription: message, metadata: metadata))
        case .unsupportedContent(let entries):
            self = .unsupportedTranscriptContent(.init(unsupportedContent: entries, debugDescription: message, metadata: metadata))
        }
    }

    /// A failure's shared metadata: its HTTP status, the provider's code for it and the company that failed, each
    /// when known.
    package static func failureMetadata(status: Int?, code: String?, provider: String?) -> [String: any Sendable] {
        var metadata: [String: any Sendable] = [:]
        metadata[LanguageModelMetadataKey.status] = status
        metadata[LanguageModelMetadataKey.errorCode] = code
        metadata[LanguageModelMetadataKey.provider] = provider
        return metadata
    }
}
