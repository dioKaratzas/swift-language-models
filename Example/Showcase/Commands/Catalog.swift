import Foundation
import FoundationModels
import OpenRouterLanguageModels
import UniformTypeIdentifiers

/// The typed catalog: every model OpenRouter listed when the package was generated, with its capabilities, context
/// size and prices, offline and without a key.
///
/// Each catalog model is also a static member, such as `.anthropicClaudeHaiku5_5`, and `catalogModels` lists them all
/// for an app that lets people pick one.
struct Catalog: Command {
    let name = "catalog"
    let summary = "Browse the model catalog by capability, with prices"
    let usage = "[capability] [words]"
    let needsKey = false

    func run(_ arguments: [String]) async throws {
        let all = OpenRouterModel.catalogModels
        var models = all
        for word in arguments {
            if let capability = Capability(rawValue: word) {
                models = models.filter(capability.isSupported)
            } else {
                models = models.filter { $0.id.rawValue.localizedCaseInsensitiveContains(word) }
            }
        }

        // Models whose price depends on the request, such as routers, go last.
        models.sort { ($0.pricing?.prompt ?? .greatestFiniteMagnitude) < ($1.pricing?.prompt ?? .greatestFiniteMagnitude) }

        print(Style.bold("Model".padded(to: 50) + "Context".padded(to: 9) + "Input".padded(to: 12) + "Output"))
        for model in models {
            let context = model.contextSize?.formatted(.number.notation(.compactName)) ?? "?"
            let input = model.pricing.map { ($0.prompt * 1_000_000).perMillion } ?? "varies"
            let output = model.pricing.map { ($0.completion * 1_000_000).perMillion } ?? "varies"
            print(model.id.rawValue.padded(to: 50) + context.padded(to: 9) + input.padded(to: 12) + output)
        }
        print(Style.dim("\n\(models.count) of \(all.count) models, cheapest first. Prices are US dollars per million tokens."))
        if arguments.isEmpty {
            let capabilities = Capability.allCases.map(\.rawValue).joined(separator: ", ")
            print(Style.dim("Narrow it by capability (\(capabilities)) and by words in the id: `showcase catalog vision claude`."))
        }
    }

    enum Capability: String, CaseIterable {
        case tools, vision, reasoning, guided, images

        func isSupported(by model: OpenRouterModel<ContextOptions.ReasoningLevel>) -> Bool {
            switch self {
            case .tools: model.capabilities.contains(.toolCalling)
            case .vision: model.capabilities.contains(.vision)
            case .reasoning: model.capabilities.contains(.reasoning)
            case .guided: model.capabilities.contains(.guidedGeneration)
            case .images: model.supportsDataEntryType(.image)
            }
        }
    }
}

extension Decimal {
    /// A price per million tokens, such as `$0.10`, or `free`.
    fileprivate var perMillion: String {
        self == 0 ? "free" : formatted(.currency(code: "USD").precision(.fractionLength(2...3)))
    }
}
