// snippet.hide
import FoundationModels
import LanguageModels
import OpenRouterLanguageModels
import UniformTypeIdentifiers

func catalog() {
    // snippet.show
    // snippet.catalog
    let haiku = OpenRouterModel.anthropicClaudeHaiku5_5
    print(haiku.contextSize ?? 0)  // The context window, in tokens
    print(haiku.capabilities.contains(.vision))  // Whether it reads images
    print(haiku.reasoningEfforts.map(\.rawValue))  // The efforts it accepts, highest first

    if let prices = haiku.pricing?.prices(forPromptTokens: 150_000) {
        print(prices.prompt * 1_000_000)  // US dollars per million tokens of a long prompt
    }
    // snippet.end
    // snippet.hide
}

func picker() {
    // snippet.show
    // snippet.picker
    let visionModels = OpenRouterModel.catalogModels.filter { $0.capabilities.contains(.vision) }
    let picked = OpenRouterModel(catalogID: "anthropic/claude-haiku-5.5")
    // snippet.end
    // snippet.hide
    _ = (visionModels, picked)
}

// snippet.show
// snippet.details
func summary(of model: some DetailedLanguageModel) -> String {
    let details = model.details
    var facts = [details.displayName]
    if let contextSize = details.contextSize {
        facts.append("\(contextSize) tokens of context")
    }
    if model.capabilities.contains(.toolCalling) {
        facts.append("calls tools")
    }
    if !details.reasoningEfforts.isEmpty {
        facts.append("reasons at \(details.reasoningEfforts.count) levels")
    }
    return facts.joined(separator: ", ")
}
// snippet.end

// snippet.hide
// FoundationModels 2.1.14 comes with Xcode 27.2, the first SDK with data attachments and data entries.
#if canImport(FoundationModels, _version: 2.1.14)
// snippet.show
// snippet.dataKinds
@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
func readsPDFs(_ model: some DetailedLanguageModel) async throws -> Bool {
    try await model.supportsDataAttachmentType(.pdf)
}
// snippet.end
// snippet.hide
#endif
