/// The keys of the metadata facts that only OpenAI's models report about an answer, which start with `openAI.`, so they
/// never collide with another provider's keys.
///
/// The facts every provider reports, such as the model, the response id and the request id, use the bare keys of
/// `LanguageModelMetadataKey`. Saved transcripts keep the keys, so their spellings never change.
public enum OpenAIMetadataKey {
    /// The `phase` of each of an answer's messages, such as `commentary` or `final_answer`, on the entry that ends the
    /// answer: a list of structures with a `phase` and the `length` of the message's text, in characters. A guided
    /// answer's message that doesn't decode, such as a `commentary` preamble, stays out of the answer's text, so its
    /// structure keeps the text itself under `heldText`, with a `length` of 0. Each message goes back with its phase
    /// on later turns.
    public static let phases = "openAI.phases"
}
