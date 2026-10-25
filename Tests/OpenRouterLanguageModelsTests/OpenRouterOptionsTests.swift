import LanguageModels
import Testing

@testable import OpenRouterLanguageModels

@Suite("OpenRouter options")
struct OpenRouterOptionsTests {
    @Test func `a setting goes in the body only when every model lists its parameter, and is noted when it doesn't`() {
        var listed = ListedParameters([.frequencyPenalty, .stop, .logitBias])
        let options = OpenRouterOptions(
            frequencyPenalty: 0.5, presencePenalty: 0.2, stopSequences: ["END"], logitBias: [50_256: -100, 13: 2.5],
            verbosity: .low, serviceTier: .flex, endUserID: "user-1")

        let json = options.json(listedIn: &listed)

        #expect(json.members.map(\.key) == ["frequency_penalty", "stop", "logit_bias", "service_tier", "user"])
        #expect(JSONValue.object(json)["logit_bias"]?.text == #"{"13":2.5,"50256":-100}"#)
        #expect(listed.unlisted == [.presencePenalty, .verbosity])
    }

    @Test func `settings left unset send nothing and note nothing`() {
        var listed = ListedParameters([])

        #expect(OpenRouterOptions().json(listedIn: &listed).members.isEmpty)
        #expect(listed.unlisted.isEmpty)
    }
}
