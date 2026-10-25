import LanguageModels

/// The parameters that every model of a request lists, and the settings left out because a model doesn't list theirs.
struct ListedParameters {
    /// The parameters that every model lists.
    let parameters: Set<OpenRouterParameter>

    /// The parameters of the settings left out, in the order the body has them.
    private(set) var unlisted: [OpenRouterParameter] = []

    init(_ parameters: Set<OpenRouterParameter>) {
        self.parameters = parameters
    }

    /// Whether every model lists a parameter.
    func contains(_ parameter: OpenRouterParameter) -> Bool {
        parameters.contains(parameter)
    }

    /// A setting's value when every model lists its parameter; otherwise `nil`, and the parameter is noted as left out.
    mutating func value(of parameter: OpenRouterParameter, _ value: JSONValue?) -> JSONValue? {
        guard value == nil || parameters.contains(parameter) else {
            unlisted.append(parameter)
            return nil
        }
        return value
    }
}
