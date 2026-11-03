package import LanguageModels

/// The role of the input message the instructions go in, as a dialect's ``ResponsesDialect/instructionsRole`` picks
/// it.
package struct InstructionsRole: ProviderVocabulary {
    /// Instructions from the app's developer, which reasoning models read ahead of the person's messages.
    package static let developer: Self = "developer"

    /// System instructions, as models before reasoning models take them.
    package static let system: Self = "system"

    package let rawValue: String

    package init(rawValue: String) {
        self.rawValue = rawValue
    }
}
