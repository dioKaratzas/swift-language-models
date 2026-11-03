package import LanguageModels

extension RequestRetries {
    /// The standard retries without their waits, so a test that retries finishes at once.
    ///
    /// - Parameter limit: The most times a request is sent again.
    /// - Returns: The retries.
    package static func immediate(limit: Int = RequestRetries.standard.limit) -> Self {
        RequestRetries(limit: limit, initialDelay: .zero)
    }
}
