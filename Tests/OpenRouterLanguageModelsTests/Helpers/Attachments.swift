import Foundation
import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

@testable import OpenRouterLanguageModels

#if canImport(FoundationModels, _version: 2.1.14)
/// A data attachment of any kind, for prompts.
@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
struct FileAttachment: DataAttachmentRepresentable {
    let transcriptRepresentation: Transcript.DataAttachment

    init(_ attachment: Transcript.DataAttachment) {
        transcriptRepresentation = attachment
    }

    /// An attachment of bytes of a kind.
    init(_ type: UTType, _ data: Data) {
        self.init(Transcript.DataAttachment(contentType: type, content: data))
    }
}
#endif

/// A one-page PDF that shows a line of text in Helvetica, written out byte by byte, so tests need no PDF files.
///
/// - Parameter text: The line, in ASCII.
/// - Returns: The PDF's bytes.
func pdfDocument(showing text: String) -> Data {
    let escaped = text.replacing("\\", with: "\\\\").replacing("(", with: "\\(").replacing(")", with: "\\)")
    let content = "BT /F1 24 Tf 72 720 Td (\(escaped)) Tj ET"
    let objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
        "<< /Length \(content.utf8.count) >>\nstream\n\(content)\nendstream",
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    var pdf = "%PDF-1.4\n"
    var offsets: [Int] = []
    for (index, object) in objects.enumerated() {
        offsets.append(pdf.utf8.count)
        pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
    }
    let table = pdf.utf8.count
    pdf += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
    for offset in offsets {
        pdf += String(repeating: "0", count: 10 - String(offset).count) + "\(offset) 00000 n \n"
    }
    pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(table)\n%%EOF\n"
    return Data(pdf.utf8)
}

/// The body of the request for a transcript, built straight from it, without the checks a session makes first.
func requestBody(_ entries: [Transcript.Entry], model: OpenRouterLanguageModel<some ModelEffort>) throws -> JSONValue {
    let request = LanguageModelExecutorGenerationRequest(
        id: UUID(), transcript: Transcript(entries: entries), enabledTools: [], generationOptions: GenerationOptions(),
        contextOptions: ContextOptions(), metadata: [:])
    return try ChatCompletionRequest(request, model: model).body
}

/// A prompt entry with an attachment and no text.
func attachmentPrompt(_ attachment: Transcript.Attachment, label: String? = nil) -> Transcript.Entry {
    .prompt(Transcript.Prompt(segments: [.attachment(.init(content: attachment, label: label))]))
}

/// The content parts of a message, or none when its content is a string.
func parts(_ message: JSONValue?) -> [JSONValue] {
    elements(message?["content"])
}

/// The bytes of a part's data URL, such as an `image_url` part's.
func dataURL(_ part: JSONValue?) -> DataURL? {
    (part?["image_url"]?["url"] ?? part?["video_url"]?["url"] ?? part?["file"]?["file_data"])?.stringValue.flatMap(DataURL.init)
}
