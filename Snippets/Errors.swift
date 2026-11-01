// snippet.hide
import Foundation
import FoundationModels
import OpenRouterLanguageModels

func errors(session: LanguageModelSession) async throws {
    // snippet.show
    // snippet.errors
    do {
        let response = try await session.respond(to: "Plan dinner.")
        print(response.content)
    } catch LanguageModelError.rateLimited(let limit) {
        print("Try again after \(limit.resetDate ?? .now).")
    } catch LanguageModelError.contextSizeExceeded(let exceeded) {
        print("The conversation needs \(exceeded.tokenCount) tokens, and the model takes \(exceeded.contextSize).")
    } catch let error as OpenRouterError where error.code == .paymentRequired {
        print("The account is out of credits.")
    }
    // snippet.end
    // snippet.hide
}

func metadata(session: LanguageModelSession) async throws {
    // snippet.show
    // snippet.metadata
    let response = try await session.respond(to: "Plan dinner.", options: GenerationOptions(maximumResponseTokens: 300))

    if let dollars = response.usage.openRouter.cost {
        print("It cost $\(dollars).")
    }
    if case .response(let answer)? = response.transcriptEntries.last {
        if let host = answer.openRouter.provider {
            print("\(host) answered.")
        }
        if answer.openRouter.finishReason == .length {
            print("The answer was cut short at its token limit.")
        }
    }
    // snippet.end
    // snippet.hide
}

func cost(session: LanguageModelSession) async throws {
    // snippet.show
    // snippet.cost
    let response = try await session.respond(to: "Plan dinner from what's in the fridge.")

    // Each round of tool calls is a request of its own, and the entry that ends each request has its cost.
    let cost = response.transcriptEntries.reduce(Decimal.zero) { total, entry in
        switch entry {
        case .toolCalls(let calls): total + (calls.openRouter.usage.cost ?? 0)
        case .response(let answer): total + (answer.openRouter.usage.cost ?? 0)
        default: total
        }
    }
    print("It cost $\(cost).")
    // snippet.end
    // snippet.hide
}
