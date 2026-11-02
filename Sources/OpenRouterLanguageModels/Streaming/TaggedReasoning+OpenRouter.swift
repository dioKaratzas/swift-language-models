import FoundationModels
import LanguageModels

extension TaggedReasoning {
    /// The metadata key under which a reasoning entry keeps the block as the model wrote it.
    static let metadataKey = "openRouter.taggedReasoning"

    /// The block to send back at the start of an answer's text, as its reasoning entry keeps it, or `nil` when the
    /// entry keeps none.
    static func block(of reasoning: Transcript.Reasoning) -> String? {
        if case .string(let block)? = reasoning.metadata[metadataKey]?.kind { block } else { nil }
    }
}
