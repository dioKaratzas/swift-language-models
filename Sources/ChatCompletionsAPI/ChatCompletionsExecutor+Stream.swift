package import Foundation
package import FoundationModels
package import UniformTypeIdentifiers

extension ChatCompletionsExecutor {
    /// One streamed chunk, as a provider reads its own members of it.
    package struct Chunk {
        /// The chunk's JSON.
        package let data: Data

        /// Decodes the provider's members of the chunk from its JSON.
        ///
        /// - Throws: An error when the chunk doesn't decode as the type.
        package func decode<T: Decodable>(_ type: T.Type) throws -> T {
            try ChatCompletionChunk.decoder.decode(type, from: data)
        }
    }

    /// What a chunk's provider members add to the answer.
    package struct ChunkOutput {
        /// Reasoning text to show before the chunk's answer text, empty to start the reasoning entry without text, or
        /// `nil` when the chunk carries no reasoning.
        package var reasoning: String?

        /// Data the model generated, such as an image, each sent as a data entry of its own after the chunk's other
        /// output.
        package var generatedData: [GeneratedData]

        package init(reasoning: String? = nil, generatedData: [GeneratedData] = []) {
            self.reasoning = reasoning
            self.generatedData = generatedData
        }

        /// Data a model generated, of a kind.
        package struct GeneratedData {
            package let contentType: UTType
            package let content: Data

            package init(contentType: UTType, content: Data) {
                self.contentType = contentType
                self.content = content
            }
        }
    }

    /// What the provider adds to an answer's facts.
    package struct Facts {
        /// The company whose servers ran the model, as `LanguageModelMetadataKey.provider` names it, once known.
        package var host: String?

        /// The facts the provider adds to the metadata of the entry that ends the answer.
        package var metadata: [String: any ConvertibleToGeneratedContent]

        /// The facts the provider adds to the metadata of the answer's usage.
        package var usageMetadata: [String: any ConvertibleToGeneratedContent]

        /// The signature of the answer's reasoning entry, such as reasoning in the provider's form that goes back on
        /// later turns, or `nil` when there's none.
        package var reasoningSignature: Data?

        package init(
            host: String? = nil,
            metadata: [String: any ConvertibleToGeneratedContent] = [:],
            usageMetadata: [String: any ConvertibleToGeneratedContent] = [:],
            reasoningSignature: Data? = nil
        ) {
            self.host = host
            self.metadata = metadata
            self.usageMetadata = usageMetadata
            self.reasoningSignature = reasoningSignature
        }
    }
}
