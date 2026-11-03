import APIFormat
package import FoundationModels
package import LanguageModels

/// What a dialect's ``ResponsesDialect/body(_:)`` reads of a request: the settings the app asked for, and what the
/// format's own members carry.
///
/// Only the format's executor creates one, so the hook sees the request as the format read it, and never the
/// transcript or the format's members themselves.
package struct BodyContext {
    /// Whether the model may or must call the session's tools, as the app asked.
    package let toolCallingMode: GenerationOptions.ToolCallingMode?

    /// Whether the session has tools, which the format sends as functions.
    package let hasSessionTools: Bool

    /// Whether the request has a response schema, which the format sends as `text.format`.
    package let hasSchema: Bool

    /// The sampling settings the app asked for, within the format's temperature range.
    package let sampling: Sampling

    /// The reasoning level the app asked for, or `nil` for the model's default.
    package let reasoningLevel: ContextOptions.ReasoningLevel?

    /// Whether an input item carries a PDF.
    package let carriesPDF: Bool

    /// The id of the transcript's first prompt, which stays the same for the whole session; `nil` before the first
    /// prompt.
    package let firstPromptID: String?

    init(_ request: LanguageModelExecutorGenerationRequest, sampling: Sampling, carriesPDF: Bool) {
        toolCallingMode = request.generationOptions.toolCallingMode
        hasSessionTools = !request.enabledToolDefinitions.isEmpty
        hasSchema = request.schema != nil
        self.sampling = sampling
        reasoningLevel = request.contextOptions.reasoningLevel
        self.carriesPDF = carriesPDF
        firstPromptID = request.transcript.firstPromptID
    }
}
