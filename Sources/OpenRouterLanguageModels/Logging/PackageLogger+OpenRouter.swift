import LanguageModels

extension PackageLogger {
    /// The OpenRouter model's messages: what each request sends and leaves out, retries, which model and host
    /// answered, failures and timings.
    static let openRouter = PackageLogger(category: "OpenRouter")
}
