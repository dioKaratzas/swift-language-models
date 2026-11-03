// snippet.hide
import FoundationModels
import OpenAILanguageModels

func details() {
    // snippet.show
    // snippet.details
    let luna = OpenAIModel.gpt6Luna
    print(luna.contextSize ?? 0)  // The context window, in tokens
    print(luna.capabilities.contains(.vision))  // Whether it reads images
    print(luna.reasoningEfforts.map(\.rawValue))  // ["max", "xhigh", "high", "medium", "low", "none"]
    // snippet.end
}

func pick() {
    // snippet.show
    // snippet.pick
    let visionModels = OpenAIModel.catalogModels.filter { $0.capabilities.contains(.vision) }
    let picked = OpenAIModel(catalogID: "gpt-6-luna")
    // snippet.end
    // snippet.hide
    _ = (visionModels, picked)
}
