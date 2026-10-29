import Foundation
import FoundationModels
import LanguageModels
import OpenRouterLanguageModels
import UniformTypeIdentifiers

/// Attachments: a prompt carries an image from macOS 27.0, and a file of another type, such as a PDF, from macOS 27.2
/// through `FileAttachment`.
///
/// The package sends an image as a JPEG, scaled down and without its metadata, and a file with its type.
struct Attachments: Command {
    let name = "attachments"
    let summary = "Ask about an image or a PDF"
    let usage = "<path> [question]"

    func run(_ arguments: [String]) async throws {
        guard let path = arguments.first else {
            throw UsageError("Pass the path of an image or a PDF, such as `showcase attachments ~/Desktop/receipt.pdf`.")
        }
        let file = URL(filePath: NSString(string: path).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: file.path()) else {
            throw UsageError("There's no file at \(path).")
        }
        let question = Array(arguments.dropFirst()).text(or: "What's in this file? Answer in three sentences.")

        let prompt: Prompt
        if UTType(filenameExtension: file.pathExtension)?.conforms(to: .image) == true {
            prompt = Prompt {
                question
                Attachment(imageURL: file).label(file.lastPathComponent)
            }
        } else {
            prompt = try filePrompt(question, file)
        }

        let model = OpenRouterLanguageModel(.googleGemini2_5FlashLite, apiKey: openRouterKey)
        let session = LanguageModelSession(model: model)
        let stream = session.streamResponse(to: prompt)
        var answer = Streamer()
        for try await snapshot in stream {
            answer.show(snapshot.content)
        }
        answer.finish()
        print(Footer(try await stream.collect()))
    }

    /// A prompt with a file of any type, which needs macOS 27.2 to run, and Xcode 27.2 to build.
    private func filePrompt(_ question: String, _ file: URL) throws -> Prompt {
        // FoundationModels 2.1.14 comes with Xcode 27.2, the first SDK with data attachments.
        #if canImport(FoundationModels, _version: 2.1.14)
        if #available(macOS 27.2, *) {
            let attachment = try FileAttachment(contentsOf: file)
            return Prompt {
                question
                Attachment(attachment).label(file.lastPathComponent)
            }
        }
        #endif
        throw UsageError("Files other than images need macOS 27.2, and Xcode 27.2 to build.")
    }
}
