public import FoundationModels
import LanguageModels

/// What OpenAI reported about a failure that throws Foundation Models' `LanguageModelError`, in OpenAI's own words,
/// read from the error's metadata.
///
/// `LanguageModelError.openAI` reads it. A fact OpenAI didn't report is `nil`:
///
/// ```swift
/// do {
///     let response = try await session.respond(to: "Plan dinner.")
///     print(response.content)
/// } catch let error as LanguageModelError {
///     print("Code \(error.openAI.errorCode?.rawValue ?? "none"), request id \(error.openAI.requestID ?? "none")")
/// }
/// ```
///
/// Its facts are the shared ones that `providerMetadata` also reads, with the code as an ``OpenAIError/Code``.
public struct OpenAIErrorMetadata: Sendable, Hashable {
    /// The HTTP status of the response that failed, such as 429 for a rate limit, or `nil` for a failure in the stream,
    /// which arrives after the response's HTTP 200.
    public let status: Int?

    /// The code the failure would have as an ``OpenAIError``: OpenAI's code or error type, or the package's code for
    /// the HTTP status, such as ``OpenAIError/Code/unmapped`` for a 429 without one.
    public let errorCode: OpenAIError.Code?

    /// OpenAI's id for the request that failed, which its support asks for.
    public let requestID: String?

    /// The facts in an error's metadata.
    init(_ metadata: [String: any Sendable]) {
        status = metadata[LanguageModelMetadataKey.status] as? Int
        errorCode = (metadata[LanguageModelMetadataKey.errorCode] as? String).map(OpenAIError.Code.init(rawValue:))
        requestID = metadata[LanguageModelMetadataKey.requestID] as? String
    }
}

extension LanguageModelError {
    /// What OpenAI reported about the failure, such as its code and OpenAI's id for the request.
    public var openAI: OpenAIErrorMetadata {
        OpenAIErrorMetadata(contextMetadata)
    }
}
