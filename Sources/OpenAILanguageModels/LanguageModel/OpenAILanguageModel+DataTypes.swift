// FoundationModels 2.1.14 comes with Xcode 27.2, the first SDK with data attachments and data entries.
#if canImport(FoundationModels, _version: 2.1.14)
import LanguageModels
public import UniformTypeIdentifiers

@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
extension OpenAILanguageModel {
    /// Whether the model accepts the kind of data as a prompt attachment.
    ///
    /// - Parameter type: The kind of data, such as `UTType.pdf`.
    /// - Returns: Whether the kind conforms to an attachment kind the model accepts.
    /// - Throws: Nothing; the method throws only because Foundation Models declares it so.
    public func supportsDataAttachmentType(_ type: UTType) async throws -> Bool {
        details.supportsDataAttachmentType(type)
    }

    /// Whether the model generates the kind of data: never, since the catalog lists only models that answer in text.
    ///
    /// - Parameter type: The kind of data, such as `UTType.png`.
    /// - Returns: Whether the model generates the kind.
    /// - Throws: Nothing; the method throws only because Foundation Models declares it so.
    public func supportsDataEntryType(_ type: UTType) async throws -> Bool {
        details.supportsDataEntryType(type)
    }
}
#endif
