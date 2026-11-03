public import Foundation
public import FoundationModels
public import LanguageModels
public import UniformTypeIdentifiers

/// What the catalog records about one of OpenAI's models.
///
/// Each model in the catalog is a static member whose effort type lists exactly the levels that model accepts. A model
/// picked at runtime uses `ContextOptions.ReasoningLevel` as its effort type instead.
public struct OpenAIModel<Effort: ModelEffort>: ModelDetails, Hashable {
    /// The model's OpenAI id, such as `gpt-6-luna`.
    public let id: OpenAIModelID

    /// The model's human-readable name.
    public let displayName: String

    /// When OpenAI created the model, or `nil` when the details don't record it.
    public let releaseDate: Date?

    /// The day the model's training data ends, at midnight UTC.
    public let knowledgeCutoff: Date?

    /// The day OpenAI shuts the model down, at midnight UTC.
    public let expirationDate: Date?

    /// The day the catalog stopped listing the model, at midnight UTC, as this release's catalog records it, or `nil`
    /// for a model the catalog doesn't record as removed.
    ///
    /// The catalog keeps a removed model's member, marked deprecated, and leaves it out of ``catalogModels`` and
    /// ``init(catalogID:)``. A request to the model logs an error and, in a debug build, shows a runtime warning.
    public var removalDate: Date? {
        ModelRemovals.openAI.removalDate(of: id.rawValue)
    }

    /// The size of the model's context window, in tokens.
    public let contextSize: Int?

    /// The kinds of input the model accepts, such as text, images or PDF documents.
    public let inputModalities: Set<OpenAIInputModality>

    /// The request settings the model accepts, such as `tools` or `temperature`.
    public let supportedParameters: Set<OpenAIParameter>

    /// Whether and when the model reasons.
    public let reasoning: ModelReasoning

    /// The reasoning levels the model accepts, highest first, or none when it doesn't reason.
    public let reasoningEfforts: [Effort]

    /// The level OpenAI uses when a request doesn't set one.
    public let defaultReasoningEffort: Effort?

    /// Creates a model's details.
    ///
    /// - Parameters:
    ///   - id: The model's OpenAI id.
    ///   - displayName: The model's human-readable name.
    ///   - releaseDate: When OpenAI created the model, or `nil` when it isn't known.
    ///   - knowledgeCutoff: The day the model's training data ends.
    ///   - expirationDate: The day OpenAI shuts the model down.
    ///   - contextSize: The size of the model's context window, in tokens.
    ///   - inputModalities: The kinds of input the model accepts.
    ///   - supportedParameters: The request settings the model accepts.
    ///   - reasoning: Whether and when the model reasons.
    ///   - reasoningEfforts: The reasoning levels the model accepts, highest first.
    ///   - defaultReasoningEffort: The level OpenAI uses when a request doesn't set one.
    public init(
        id: OpenAIModelID,
        displayName: String,
        releaseDate: Date? = nil,
        knowledgeCutoff: Date? = nil,
        expirationDate: Date? = nil,
        contextSize: Int? = nil,
        inputModalities: Set<OpenAIInputModality> = [.text],
        supportedParameters: Set<OpenAIParameter>,
        reasoning: ModelReasoning = .unsupported,
        reasoningEfforts: [Effort] = [],
        defaultReasoningEffort: Effort? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.releaseDate = releaseDate
        self.knowledgeCutoff = knowledgeCutoff
        self.expirationDate = expirationDate
        self.contextSize = contextSize
        self.inputModalities = inputModalities
        self.supportedParameters = supportedParameters
        self.reasoning = reasoning
        self.reasoningEfforts = reasoningEfforts
        self.defaultReasoningEffort = defaultReasoningEffort
    }

    /// What the model supports, from the request settings and input kinds it accepts.
    ///
    /// Guided generation needs `structured_outputs`, so OpenAI holds the answer to the schema.
    public var capabilities: LanguageModelCapabilities {
        var capabilities: [LanguageModelCapabilities.Capability] = []
        if supportedParameters.contains(.tools) { capabilities.append(.toolCalling) }
        if supportedParameters.contains(.structuredOutputs) { capabilities.append(.guidedGeneration) }
        if reasoning.isSupported { capabilities.append(.reasoning) }
        if inputModalities.contains(.image) { capabilities.append(.vision) }
        return LanguageModelCapabilities(capabilities)
    }

    /// The attachment kinds the model accepts: those of its input kinds.
    public var dataAttachmentTypes: Set<UTType> {
        Set(inputModalities.flatMap(\.contentTypes))
    }

    /// The data kinds the model generates besides text: none, since the catalog lists only models that answer in text.
    public var dataEntryTypes: Set<UTType> {
        []
    }

    /// Hashes the model's id, which equal details always share, so details of any effort type can be hashed.
    ///
    /// - Parameter hasher: The hasher to feed the id to.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension OpenAIModel where Effort == ContextOptions.ReasoningLevel {
    /// The same model with its efforts in their open form, so models with different effort types fit in one list.
    ///
    /// - Parameter typed: A model from the catalog.
    public init(_ typed: OpenAIModel<some ModelEffort>) {
        self.init(
            id: typed.id,
            displayName: typed.displayName,
            releaseDate: typed.releaseDate,
            knowledgeCutoff: typed.knowledgeCutoff,
            expirationDate: typed.expirationDate,
            contextSize: typed.contextSize,
            inputModalities: typed.inputModalities,
            supportedParameters: typed.supportedParameters,
            reasoning: typed.reasoning,
            reasoningEfforts: typed.reasoningEfforts.map(\.reasoningLevel),
            defaultReasoningEffort: typed.defaultReasoningEffort?.reasoningLevel
        )
    }
}
