public import FoundationModels
public import UniformTypeIdentifiers

/// A language model that carries what its provider reports about it.
///
/// The model's capabilities, and the kinds of data it accepts and generates, come from its details.
public protocol DetailedLanguageModel: LanguageModel {
    /// The type that describes the model.
    associatedtype Details: ModelDetails

    /// What the provider reports about this model.
    var details: Details { get }
}

extension DetailedLanguageModel {
    /// The capabilities from the model's details.
    public var capabilities: LanguageModelCapabilities { details.capabilities }
}

@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
extension DetailedLanguageModel {
    /// Whether the model's details list the kind of data as a prompt attachment it accepts.
    ///
    /// - Parameter type: The kind of data, such as `UTType.png`.
    /// - Returns: Whether the kind conforms to one of the details' `dataAttachmentTypes`.
    public func supportsDataAttachmentType(_ type: UTType) async throws -> Bool {
        details.supportsDataAttachmentType(type)
    }

    /// Whether the model's details list the kind of data as one it generates.
    ///
    /// - Parameter type: The kind of data, such as `UTType.png`.
    /// - Returns: Whether the kind conforms to one of the details' `dataEntryTypes`.
    public func supportsDataEntryType(_ type: UTType) async throws -> Bool {
        details.supportsDataEntryType(type)
    }
}
