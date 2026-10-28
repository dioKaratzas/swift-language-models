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

    if case .number(let dollars)? = response.usage.metadata[OpenRouterMetadataKey.cost]?.kind {
        print("It cost $\(dollars).")
    }
    if case .response(let answer)? = response.transcriptEntries.last {
        if case .string(let host)? = answer.metadata[OpenRouterMetadataKey.provider]?.kind {
            print("\(host) answered.")
        }
        if answer.openRouterFinishReason == .length {
            print("The answer was cut short at its token limit.")
        }
    }
    // snippet.end
    // snippet.hide
}
