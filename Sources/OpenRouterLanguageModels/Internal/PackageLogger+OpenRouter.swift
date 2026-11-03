import LanguageModels

extension PackageLogger {
    /// The OpenRouter model's messages: what each request sends and leaves out, retries, which model and host
    /// answered, failures and timings.
    ///
    /// It's the same category as the dialect's own `logger`, for code that runs outside a request, such as an
    /// option's initializer, where no dialect exists: the dialect's type is generic over the model's effort.
    static let openRouter = PackageLogger(category: API.name)
}
