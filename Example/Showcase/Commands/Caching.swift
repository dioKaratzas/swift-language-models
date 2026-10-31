import Foundation
import FoundationModels
import OpenRouterLanguageModels

/// Prompt caching: Claude caches the long instructions on the first turn, and the second turn reads them back from
/// the cache at a tenth of the input price.
///
/// The package marks requests for caching on its own when every model they may reach needs the mark, as Claude does.
struct Caching: Command {
    let name = "caching"
    let summary = "Two turns on Claude: a cache write, then a cheaper cache read"

    func run(_ arguments: [String]) async throws {
        let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, auth: .apiKey(openRouterKey))
        let session = LanguageModelSession(model: model, instructions: Self.styleGuide)

        var costs: [Decimal] = []
        for question in ["Which rule first covers greetings?", "And which rule first covers numbers?"] {
            print(Style.bold(question))
            let response = try await session.respond(to: question)
            print(response.content)
            print("\(Footer(response))\n")
            costs.append(response.usage.openRouter.cost ?? 0)
        }

        if let first = costs.first, let second = costs.last, first > 0 {
            let saving = ((first - second) / first).formatted(.percent.precision(.fractionLength(0)))
            print(Style.green("The second turn cost \(saving) less than the first."))
        }
    }

    /// A made-up style guide, long enough to cache: Claude caches only prompts past a minimum length, of up to 4,096
    /// tokens by model.
    static let styleGuide = (1...600).map { "Rule \($0): \(rules[$0 % rules.count])" }.joined(separator: "\n")

    static let rules = ["Greet readers by name.", "Keep sentences short.", "Spell out numbers under ten.", "Sign off with thanks."]
}
