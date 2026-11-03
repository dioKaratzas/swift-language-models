import APIFormat
package import FoundationModels
import LanguageModels

/// One of an answer's reasoning entries that goes back in a later request, as a dialect's
/// ``ChatCompletionsDialect/replayMembers(_:)`` reads it.
///
/// Only the format's executor creates one.
package struct ReplayedReasoning {
    /// The entry, with its signature and metadata.
    package let entry: Transcript.Reasoning

    /// The entry's text, or empty for a block the model wrote at the start of its answer's text, which goes back
    /// there instead.
    package let text: String

    init(_ entry: Transcript.Reasoning) {
        self.entry = entry
        text = TaggedReasoning.block(of: entry) == nil ? entry.segments.compactMap(\.text).joined() : ""
    }
}
