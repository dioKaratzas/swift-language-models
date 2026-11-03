import FoundationModels
import LanguageModels

/// The `phase` of one of an answer's messages, such as `commentary` or `final_answer`, and the length of its text, in
/// characters, as the response entry's metadata keeps them, so each message goes back on later turns with its own
/// phase.
struct MessagePhase: Equatable {
    var phase: String?
    var length = 0

    init(phase: String? = nil, length: Int = 0) {
        self.phase = phase
        self.length = length
    }

    /// A message's phase read back from an element of the metadata, or `nil` for an element that isn't one.
    init?(_ values: MetadataValues) {
        guard let length = values.integer(Field.length) else { return nil }
        self.init(phase: values.string(Field.phase), length: length)
    }

    /// The message as an element of the metadata.
    var metadataValue: GeneratedContent {
        GeneratedContent(properties: [Field.phase: phase, Field.length: length])
    }

    /// The keys of an element. Saved transcripts keep them, so they never change.
    enum Field {
        static let phase = "phase"
        static let length = "length"
    }

    /// An answer's text split into its messages, each with its phase, or the whole text as one message with the last
    /// phase when the lengths don't add up to the text, as when the text changed.
    ///
    /// - Parameters:
    ///   - text: The answer's text.
    ///   - phases: The answer's messages, in their order.
    /// - Returns: The messages' texts and phases, leaving out empty texts.
    static func split(_ text: String, into phases: [MessagePhase]) -> [(text: String, phase: String?)] {
        guard phases.map(\.length).reduce(0, +) == text.count else {
            return text.isEmpty ? [] : [(text, phases.last?.phase)]
        }
        var rest = Substring(text)
        return phases.compactMap { message in
            let part = rest.prefix(message.length)
            rest = rest.dropFirst(message.length)
            return part.isEmpty ? nil : (String(part), message.phase)
        }
    }
}
