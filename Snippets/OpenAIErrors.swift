// snippet.hide
import Foundation
import FoundationModels
import OpenAILanguageModels

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
    } catch let error as OpenAIError where error.isQuotaExhausted {
        print("The account is out of credits.")
    }
    // snippet.end
    // snippet.hide
}

func metadata(session: LanguageModelSession) async throws {
    // snippet.show
    // snippet.metadata
    let response = try await session.respond(to: "Plan dinner.", options: GenerationOptions(maximumResponseTokens: 300))
    print("Reasoning tokens:", response.usage.output.reasoningTokenCount)
    if case .response(let answer)? = response.transcriptEntries.last {
        if case .string(let requestID)? = answer.metadata[LanguageModelMetadataKey.requestID]?.kind {
            print("OpenAI's id for the request: \(requestID)")
        }
        if case .string(let reason)? = answer.metadata[LanguageModelMetadataKey.finishReason]?.kind,
            FinishReason(rawValue: reason) == .length
        {
            print("The answer was cut short at its token limit.")
        }
    }
    // snippet.end
    // snippet.hide
}
