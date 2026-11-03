import Foundation
package import FoundationModels

/// What Foundation Models asks an executor for.
package func generationRequest(
    _ entries: [Transcript.Entry],
    tools: [Transcript.ToolDefinition] = [],
    schema: GenerationSchema? = nil,
    options: GenerationOptions = GenerationOptions(),
    metadata: [String: any ConvertibleToGeneratedContent] = [:]
) -> LanguageModelExecutorGenerationRequest {
    LanguageModelExecutorGenerationRequest(
        id: UUID(), transcript: Transcript(entries: entries), enabledTools: tools, schema: schema, generationOptions: options,
        contextOptions: ContextOptions(), metadata: metadata)
}

/// A prompt entry with the given segments.
package func prompt(_ segments: Transcript.Segment...) -> Transcript.Entry {
    .prompt(Transcript.Prompt(segments: segments))
}

/// A rating whose stars have a range, which the portable schema moves into the description.
@Generable
package struct Rating {
    @Guide(.range(1...5))
    package var stars: Int
}

/// A tool that looks up a word, and answers with the word.
package struct LookUpTool: Tool {
    package let name = "lookUp"
    package let description = "Looks up a word."

    @Generable
    package struct Arguments {
        package var word: String
    }

    package init() {}

    package func call(arguments: Arguments) async throws -> String {
        arguments.word
    }
}
