// snippet.hide
import FoundationModels
import OpenRouterLanguageModels
import UniformTypeIdentifiers

func catalog() {
    // snippet.show
    // snippet.catalog
    let haiku = OpenRouterModel.anthropicClaudeHaiku5_5
    print(haiku.contextSize ?? 0)  // The context window, in tokens
    print(haiku.maximumOutputTokens ?? 0)  // The most tokens one answer can have
    print(haiku.capabilities.contains(.vision))  // Whether it reads images
    print(haiku.reasoningEfforts.map(\.rawValue))  // The efforts it accepts, highest first
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

func routers() {
    // snippet.show
    // snippet.routers
    let auto = OpenRouterLanguageModel(
        .openrouterAuto,
        options: OpenRouterOptions(
            autoRouter: OpenRouterAutoRouter(allowedModels: ["anthropic/*", "openai/gpt-5*"], costTier: .medium)
        ),
        apiKey: { try await keyStore.openRouterKey() }
    )
    let coder = OpenRouterLanguageModel(
        .openrouterParetoCode,
        options: OpenRouterOptions(minimumCodingScore: 0.66),
        apiKey: { try await keyStore.openRouterKey() }
    )
    // snippet.end
    // snippet.hide
    _ = (auto, coder)
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

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openRouterKey() async throws -> String { "" }
}

let keyStore = KeyStore()
