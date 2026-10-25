/// A change a request makes to what the app asked for, so that its models and OpenRouter take it.
///
/// Each one is likely a mistake in the app, so the request logs it.
enum RequestAdjustment: Equatable {
    /// Settings left out because the model or a fallback doesn't list their parameters, in the order the body has
    /// them.
    case unlistedParameters([OpenRouterParameter])

    /// Request metadata left out, by key: pairs past OpenRouter's limits of 16 pairs, 64-character keys and
    /// 512-character values, and pairs whose value isn't a string.
    case droppedMetadata(keys: [String])

    /// A reasoning level sent as another effort, the nearest that every model accepts, or left out when no effort
    /// they accept is near it.
    case movedEffort(requested: String, sent: String?)
}

extension RequestAdjustment {
    /// What the request changed, for the log, without the metadata's keys, which the app may have made from personal
    /// data.
    ///
    /// - Parameter model: The id of the model the request names first.
    /// - Returns: A sentence that names the model.
    func message(model: String) -> String {
        switch self {
        case .unlistedParameters(let parameters):
            let names = parameters.map(\.rawValue).joined(separator: ", ")
            return "The request to \(model) leaves out \(names), which the model or a fallback doesn't list."
        case .droppedMetadata:
            return """
                The request to \(model) leaves out metadata that OpenRouter doesn't take: values that aren't strings, and \
                pairs past its limits of 16 pairs, keys up to 64 characters and values up to 512.
                """
        case .movedEffort(let requested, let sent?):
            return "The request to \(model) sends the reasoning level \(requested) as \(sent), the nearest effort its models accept."
        case .movedEffort(let requested, nil):
            return "The request to \(model) leaves out the reasoning level \(requested), since its models accept no effort near it."
        }
    }

    /// The runtime warning: the message, and the keys of metadata left out, which the warning's log entry keeps
    /// private.
    ///
    /// - Parameter model: The id of the model the request names first.
    /// - Returns: The message, and the keys after it.
    func warning(model: String) -> String {
        guard case .droppedMetadata(let keys) = self else { return message(model: model) }
        return "\(message(model: model)) Keys: \(keys.joined(separator: ", "))."
    }
}
