// FoundationModels 2.1.14 comes with Xcode 27.2, the first SDK with data attachments and data entries.
#if canImport(FoundationModels, _version: 2.1.14)
import LanguageModels
public import UniformTypeIdentifiers

@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
extension OpenRouterLanguageModel {
    /// Whether the model and each of its fallbacks accept the kind of data as a prompt attachment.
    ///
    /// A PDF is accepted by every model, since OpenRouter reads it for a model that can't, unless
    /// ``OpenRouterOptions/pdfEngine`` is ``OpenRouterPDFEngine/native``.
    ///
    /// - Parameter type: The kind of data, such as `UTType.png`.
    /// - Returns: Whether the kind conforms to an attachment kind that every model of the request accepts.
    /// - Throws: Nothing; the method throws only because Foundation Models declares it so.
    public func supportsDataAttachmentType(_ type: UTType) async throws -> Bool {
        OpenRouterInputModality(carrying: type).map(attachmentInputs.contains) ?? false
    }

    /// Whether the model and each of its fallbacks generate the kind of data.
    ///
    /// - Parameter type: The kind of data, such as `UTType.png`.
    /// - Returns: Whether the kind conforms to a data kind that every model of the request generates.
    /// - Throws: Nothing; the method throws only because Foundation Models declares it so.
    public func supportsDataEntryType(_ type: UTType) async throws -> Bool {
        sharedDetails.supportsDataEntryType(type)
    }
}
#endif
