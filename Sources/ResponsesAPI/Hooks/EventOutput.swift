package import LanguageModels

/// What an event's provider members add to the answer, as a dialect's ``ResponsesDialect/observe(_:into:)`` returns
/// it.
package struct EventOutput {
    /// Data the model generated, such as an image, each sent as a data entry of its own after the event's other
    /// output.
    package var generatedData: [GeneratedData]

    package init(generatedData: [GeneratedData] = []) {
        self.generatedData = generatedData
    }
}
