import Foundation
import FoundationModels
import LanguageModels

/// Foundation Models' sampling options as OpenRouter's parameters.
struct Sampling {
    var temperature: Double?
    var topP: Double?
    var topK: Int?
    var seed: UInt64?

    /// Greedy sampling becomes temperature 0, and also `top_k` 1 when the model takes it. Temperatures are clamped to
    /// OpenRouter's 0 to 2, and probability thresholds to 0 to 1.
    init(_ options: GenerationOptions, parameters: Set<OpenRouterParameter>) {
        temperature = options.temperature.map { min(max($0, 0), 2) }
        switch options.samplingMode?.kind {
        case .greedy?:
            temperature = 0
            topK = parameters.contains(.topK) ? 1 : nil
        case .randomTopK(let k, let seed)?:
            topK = k
            self.seed = seed
        case .randomProbabilityThreshold(let threshold, let seed)?:
            topP = min(max(threshold, 0), 1)
            self.seed = seed
        case nil:
            break
        @unknown default:
            break
        }
    }

    /// A seed as a number that hosts read as a signed 64-bit integer. A seed of 2^63 or more loses its top bit, so every
    /// seed is sent, and each one as the same number on every platform.
    static func json(seed: UInt64) -> JSONValue {
        let folded = seed & UInt64(Int64.max)
        return Int(exactly: folded).map(JSONValue.integer) ?? .largeInteger(Decimal(folded))
    }
}
