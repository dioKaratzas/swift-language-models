import LanguageModels

extension OpenAIError: LoggableError {
    package var loggedError: LoggedError {
        LoggedError(kind: "OpenAIError", status: status, code: code.rawValue, host: nil)
    }
}
