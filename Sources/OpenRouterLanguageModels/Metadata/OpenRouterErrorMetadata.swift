public import FoundationModels
public import LanguageModels

/// What OpenRouter reported about a failure that throws Foundation Models' `LanguageModelError`, in OpenRouter's own
/// words, read from the error's metadata.
///
/// `LanguageModelError.openRouter` reads it. A fact OpenRouter didn't report is `nil`:
///
/// ```swift
/// do {
///     let response = try await session.respond(to: "Plan dinner.")
///     print(response.content)
/// } catch LanguageModelError.rateLimited(let limit) {
///     print("Try again after \(limit.resetDate ?? .now).")
/// } catch let error as LanguageModelError where error.openRouter.limitSource == .apiKey {
///     print("The key's spending budget ran out.")
/// }
/// ```
///
/// Its facts are the shared ones that `providerMetadata` also reads, as OpenRouter's types, and ``limitSource`` from
/// ``OpenRouterMetadataKey/limitSource``.
public struct OpenRouterErrorMetadata: Sendable, Hashable {
    /// The HTTP status of the response that failed, such as 429 for a rate limit, or `nil` for a failure in the stream,
    /// which arrives after the response's HTTP 200.
    public let status: Int?

    /// The code the failure would have as an ``OpenRouterError``, such as ``OpenRouterError/Code/budgetExceeded``.
    public let errorCode: OpenRouterError.Code?

    /// The host that failed, such as `Anthropic`, when OpenRouter names one.
    public let provider: OpenRouterProviderName?

    /// The budget or limit the request ran into, such as the key's spending budget, when OpenRouter names one.
    public let limitSource: LimitSource?

    /// The facts in an error's metadata.
    init(_ metadata: [String: any Sendable]) {
        status = metadata[LanguageModelMetadataKey.status] as? Int
        errorCode = (metadata[LanguageModelMetadataKey.errorCode] as? String).map(OpenRouterError.Code.init(rawValue:))
        provider = (metadata[LanguageModelMetadataKey.provider] as? String).map(OpenRouterProviderName.init(rawValue:))
        limitSource = (metadata[OpenRouterMetadataKey.limitSource] as? String).map(LimitSource.init(rawValue:))
    }
}

extension OpenRouterErrorMetadata {
    /// The budget or limit a request ran into, as OpenRouter's `limit_source` names it.
    public struct LimitSource: ProviderVocabulary {
        /// The key's spending budget.
        public static let apiKey: Self = "api_key"

        /// The most requests a key may have in flight at once.
        public static let inFlightBudget: Self = "openrouter_in_flight_budget"

        /// The source as OpenRouter's API spells it.
        public let rawValue: String

        /// Creates a source from OpenRouter's spelling of it.
        ///
        /// - Parameter rawValue: The source, such as `"api_key"`.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

extension LanguageModelError {
    /// What OpenRouter reported about the failure, such as the host that failed and the budget the request ran into.
    public var openRouter: OpenRouterErrorMetadata {
        OpenRouterErrorMetadata(contextMetadata)
    }
}
