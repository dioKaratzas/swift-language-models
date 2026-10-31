import Foundation
import FoundationModels
import OpenRouterLanguageModels

/// Guided generation: the model fills in a `@Generable` type, and each snapshot of the stream holds the part generated
/// so far, so the plan fills in on screen as it arrives.
///
/// The package sends the type's schema as the request's structured output format.
struct Guided: Command {
    let name = "guided"
    let summary = "Stream a typed trip plan that fills in as it generates"
    let usage = "[destination]"

    func run(_ arguments: [String]) async throws {
        let model = OpenRouterLanguageModel(.googleGemini2_5FlashLite, auth: .apiKey(openRouterKey))
        let session = LanguageModelSession(model: model)
        let destination = arguments.text(or: "Kyoto")

        var plan = LiveText()
        for try await snapshot in session.streamResponse(to: "Plan three days in \(destination).", generating: TripPlan.self) {
            plan.show(snapshot.content.text)
        }
        plan.finish()
    }

    @Generable
    struct TripPlan {
        @Guide(description: "A short title for the trip.")
        var title: String

        @Guide(description: "The plan for each day.", .count(3))
        var days: [Day]
    }

    @Generable
    struct Day {
        @Guide(description: "The day's theme, in a few words.")
        var theme: String

        @Guide(description: "Things to do, each a short phrase.", .count(3))
        var activities: [String]
    }
}

extension Guided.TripPlan.PartiallyGenerated {
    /// The plan so far, as text. A property the model hasn't reached yet is `nil`.
    var text: String {
        var lines = [title ?? "…"]
        for (index, day) in (days ?? []).enumerated() {
            lines.append("Day \(index + 1): \(day.theme ?? "…")")
            lines += (day.activities ?? []).map { "  • \($0)" }
        }
        return lines.joined(separator: "\n")
    }
}
