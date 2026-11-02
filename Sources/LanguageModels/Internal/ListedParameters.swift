/// The parameters that every model of a request lists, and the settings left out because a model doesn't list theirs.
///
/// A provider whose models list the parameters they take sends a setting only when every model a request may reach
/// lists its parameter, and logs the ones it left out.
package struct ListedParameters<Parameter: Hashable> {
    /// The parameters that every model lists.
    package let parameters: Set<Parameter>

    /// The parameters of the settings left out, in the order the body has them.
    package private(set) var unlisted: [Parameter] = []

    package init(_ parameters: Set<Parameter>) {
        self.parameters = parameters
    }

    /// Whether every model lists a parameter.
    package func contains(_ parameter: Parameter) -> Bool {
        parameters.contains(parameter)
    }

    /// A setting's value when every model lists its parameter; otherwise `nil`, and the parameter is noted as left out.
    package mutating func value(of parameter: Parameter, _ value: JSONValue?) -> JSONValue? {
        guard value == nil || parameters.contains(parameter) else {
            unlisted.append(parameter)
            return nil
        }
        return value
    }
}
