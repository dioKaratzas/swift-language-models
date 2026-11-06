import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenAILanguageModels
import Testing
import UniformTypeIdentifiers

/// Attachments sent to real OpenAI models: an image the package draws, and a PDF it writes.
@diagnose(DeprecatedDeclaration, as: warning)
@Suite(
    "Live: OpenAI attachments",
    .tags(.live),
    .requiresAPIKey("OPENAI_API_KEY"),
    .skipsUnavailableOpenAI,
    .timeLimit(.minutes(2))
)
struct LiveAttachmentTests {
    @Test(arguments: [LiveModel.nano, .luna, .mini])
    func `a drawn digit is read from an image`(model: LiveModel) async throws {
        let image = try #require(TestImage.seven(size: 256))
        let session = LanguageModelSession(model: try model.languageModel())

        let response = try await session.respond(options: LiveTests.short, contextOptions: model.quickContext, metadata: [:]) {
            "Which digit is drawn in this image? Reply with the digit only."
            FoundationModels.Attachment(image).label("digit")
        }

        #expect(response.content.contains("7"))
    }

    // The package's own documentation card, a network of white symbols on a purple background, which Foundation Models
    // and OpenAI both download.
    @Test func `an image at a web address is read`() async throws {
        let url = try #require(
            URL(
                string:
                    "https://raw.githubusercontent.com/ironsparrows/swift-language-models/main/Sources/LanguageModels/Documentation.docc/Assets/swift-language-models-card.png"
            ))
        let session = LanguageModelSession(model: try LiveModel.mini.languageModel())

        let response = try await session.respond(options: LiveTests.short, contextOptions: LiveModel.mini.quickContext, metadata: [:]) {
            "Is the background of this image mostly purple? Reply with yes or no only."
            FoundationModels.Attachment(imageURL: url)
        }

        #expect(response.content.localizedCaseInsensitiveContains("yes"))
    }

    #if canImport(FoundationModels, _version: 2.1.14)
    @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
    @Test func `a PDF's text is read`() async throws {
        let pdf = pdfDocument(showing: "The secret word is PELICAN.")
        let session = LanguageModelSession(model: try LiveModel.luna.languageModel())

        let response = try await session.respond(options: LiveTests.short, contextOptions: LiveModel.luna.quickContext, metadata: [:]) {
            "What is the secret word in this document? Reply with the word only."
            FoundationModels.Attachment(FileAttachment(pdf, type: .pdf)).label("note")
        }

        #expect(response.content.localizedCaseInsensitiveContains("pelican"))
    }
    #endif

    @Test func `the models' attachment kinds match the catalog's`() throws {
        let nano = try #require(OpenAIModel(catalogID: LiveModel.nano.id))
        let luna = try #require(OpenAIModel(catalogID: LiveModel.luna.id))

        #expect(nano.supportsDataAttachmentType(.png))
        #expect(!nano.supportsDataAttachmentType(.wav))
        #expect(luna.supportsDataAttachmentType(.pdf))
    }
}
