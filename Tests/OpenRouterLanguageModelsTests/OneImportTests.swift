// This file imports only the module an app imports, so it stops compiling when a vocabulary needs another import.
import OpenRouterLanguageModels
import Testing

/// Each vocabulary's word as a string literal, as the value prints, and the literal itself.
private let words: [(printed: String, literal: String)] = [
    (("anthropic/claude-haiku-5.5" as OpenRouterModelID).description, "anthropic/claude-haiku-5.5"),
    (("Anthropic" as OpenRouterProviderName).description, "Anthropic"),
    (("top_p" as OpenRouterParameter).description, "top_p"),
    (("image" as OpenRouterInputModality).description, "image"),
    (("image" as OpenRouterOutputModality).description, "image"),
    (("flex" as OpenRouterServiceTier).description, "flex"),
    (("low" as OpenRouterVerbosity).description, "low"),
    (("cloudflare-ai" as OpenRouterPDFEngine).description, "cloudflare-ai"),
    (("price" as OpenRouterProviderSort).description, "price"),
    (("fp8" as OpenRouterQuantization).description, "fp8"),
    (("cli-agent" as OpenRouterAppCategory).description, "cli-agent"),
    (("high" as OpenRouterSearchContextSize).description, "high"),
    (("exa" as OpenRouterWebSearchEngine).description, "exa"),
    (("fast" as OpenRouterWebSearchMode).description, "fast"),
    (("openrouter" as OpenRouterWebFetchEngine).description, "openrouter"),
    (("medium" as OpenRouterAutoRouter.CostTier).description, "medium"),
    (("payment_required" as OpenRouterError.Code).description, "payment_required"),
    (("nitro" as OpenRouterRouting.Variant).description, "nitro"),
    (("length" as OpenRouterFinishReason).description, "length"),
]

@Suite("One import")
struct OneImportTests {
    @Test(arguments: words)
    func `every vocabulary takes a string literal and prints it, with only this module imported`(printed: String, literal: String) {
        #expect(printed == literal)
    }
}
