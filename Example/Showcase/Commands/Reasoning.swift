import Foundation
import FoundationModels
import LanguageModels
import OpenRouterLanguageModels

/// Reasoning levels: DeepSeek V4 Flash reasons at the level a request asks for, and the transcript keeps its reasoning
/// in an entry of its own, before the answer.
///
/// DeepSeek returns its reasoning as plain text. Some models reason without showing it, or skip reasoning on an easy
/// question, as Claude may. A catalog model lists exactly the levels it accepts, highest first, in `reasoningEfforts`.
struct Reasoning: Command {
    let name = "reasoning"
    let summary = "Show the model's reasoning, dimmed, before its answer"
    let usage = "[level] [question]"

    func run(_ arguments: [String]) async throws {
        let model = OpenRouterLanguageModel(.deepseekDeepseekV4Flash, apiKey: openRouterKey)
        let picked = model.details.reasoningEfforts.first { $0.rawValue == arguments.first }
        let effort = picked ?? .high
        let question = Array(arguments.dropFirst(picked == nil ? 0 : 1))
            .text(or: "A bat and a ball cost $1.10, and the bat costs $1 more than the ball. What does the ball cost?")

        print(Style.dim("Reasoning at \(effort.rawValue)…"))
        let session = LanguageModelSession(model: model)
        let response = try await session.respond(to: question, contextOptions: ContextOptions(reasoningLevel: effort.reasoningLevel))

        for case .reasoning(let reasoning) in response.transcriptEntries {
            for case .text(let text) in reasoning.segments {
                print(Style.dim(text.content))
            }
        }
        print("\n" + response.content)
        print(Footer(response))
    }
}
