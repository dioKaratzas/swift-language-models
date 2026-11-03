// snippet.hide
import CoreGraphics
import Foundation
import FoundationModels
import OpenAILanguageModels
import UniformTypeIdentifiers

func image(session: LanguageModelSession, receipt: CGImage) async throws {
    // snippet.show
    // snippet.image
    let response = try await session.respond {
        "What did I spend on dinner?"
        Attachment(receipt).label("receipt")
    }
    // snippet.end
    // snippet.hide
    _ = response
}

// FoundationModels 2.1.14 comes with Xcode 27.2, the first SDK with data attachments and data entries.
#if canImport(FoundationModels, _version: 2.1.14)
// snippet.show
// snippet.file
@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
func leaseEnd(of lease: URL, in session: LanguageModelSession) async throws -> String {
    let file = try FileAttachment(contentsOf: lease)
    let response = try await session.respond {
        "When does the lease end?"
        Attachment(file).label(lease.lastPathComponent)
    }
    return response.content
}
// snippet.end
// snippet.hide
#endif

func kinds() {
    // snippet.show
    // snippet.kinds
    print(OpenAIModel.gpt6Luna.supportsDataAttachmentType(.pdf))  // true
    print(OpenAIModel.gpt5_2.supportsDataAttachmentType(.pdf))  // false
    print(OpenAIModel.gpt6Luna.supportsDataAttachmentType(.wav))  // false
    // snippet.end
}
