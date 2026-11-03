import LanguageModels

extension OpenRouterError: LoggableError {
    package var loggedError: LoggedError {
        LoggedError(kind: "OpenRouterError", status: status, code: code.rawValue, host: providerName?.rawValue)
    }
}
