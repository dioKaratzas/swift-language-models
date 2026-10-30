// snippet.hide
import CoreGraphics
import Foundation
import FoundationModels
import OpenRouterLanguageModels
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

@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
func total(of receipt: Data, in session: LanguageModelSession) async throws -> String {
    let response = try await session.respond {
        "What's the total?"
        Attachment(FileAttachment(receipt, type: .pdf)).label("receipt.pdf")
    }
    return response.content
}
// snippet.end

// snippet.images
@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
func drawLighthouse() async throws -> [Data] {
    let artist = OpenRouterLanguageModel(.googleGemini2_5FlashImage, apiKey: { try await keyStore.openRouterKey() })
    let response = try await LanguageModelSession(model: artist).respond(to: "Draw a lighthouse at dusk.")

    var images: [Data] = []
    for case .data(let entry) in response.transcriptEntries where entry.contentType.conforms(to: .image) {
        images.append(entry.content)
    }
    return images
}
// snippet.end
// snippet.hide
#endif

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openRouterKey() async throws -> String { "" }
}

let keyStore = KeyStore()
