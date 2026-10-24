// FoundationModels 2.1.14 comes with Xcode 27.2, the first SDK with data attachments and data entries.
#if canImport(FoundationModels, _version: 2.1.14)
public import UniformTypeIdentifiers

@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
extension DetailedLanguageModel {
    /// Whether the model's details list the kind of data as a prompt attachment it accepts.
    ///
    /// - Parameter type: The kind of data, such as `UTType.png`.
    /// - Returns: Whether the kind conforms to one of the details' `dataAttachmentTypes`.
    /// - Throws: Nothing; the method throws only because Foundation Models declares it so.
    public func supportsDataAttachmentType(_ type: UTType) async throws -> Bool {
        details.supportsDataAttachmentType(type)
    }

    /// Whether the model's details list the kind of data as one it generates.
    ///
    /// - Parameter type: The kind of data, such as `UTType.png`.
    /// - Returns: Whether the kind conforms to one of the details' `dataEntryTypes`.
    /// - Throws: Nothing; the method throws only because Foundation Models declares it so.
    public func supportsDataEntryType(_ type: UTType) async throws -> Bool {
        details.supportsDataEntryType(type)
    }
}
#endif
