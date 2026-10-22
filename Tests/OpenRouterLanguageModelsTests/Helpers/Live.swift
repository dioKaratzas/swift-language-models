import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

/// The app name live requests send, so their usage shows apart in OpenRouter's analytics.
let liveAppName = "swift-language-models tests"

/// A catalog model under test, with what the tests need to know about it.
struct LiveModel: Sendable, CustomTestStringConvertible {
    /// The model's details, with its efforts as reasoning levels.
    let details: OpenRouterModel<ContextOptions.ReasoningLevel>

    /// How long marked prompts stay cached, for a model that caches only marked prompts.
    let cacheControl: OpenRouterCacheControl?

    /// A level that keeps the model reasoning at little cost.
    let reasoningLevel: ContextOptions.ReasoningLevel

    /// Whether the model's reasoning comes back signed or encrypted, for the provider to check when it's replayed.
    let signsReasoning: Bool

    init(
        _ details: OpenRouterModel<some ModelEffort>,
        cacheControl: OpenRouterCacheControl? = nil,
        reasoningLevel: ContextOptions.ReasoningLevel = .light,
        signsReasoning: Bool = false
    ) {
        self.details = OpenRouterModel(details)
        self.cacheControl = cacheControl
        self.reasoningLevel = reasoningLevel
        self.signsReasoning = signsReasoning
    }

    var testDescription: String { details.id.rawValue }

    /// The model, with the running test's API key.
    var languageModel: OpenRouterLanguageModel<ContextOptions.ReasoningLevel> {
        languageModel()
    }

    /// The model with OpenRouter's settings and the running test's API key.
    func languageModel(
        fallbacks: [OpenRouterModel<ContextOptions.ReasoningLevel>] = [],
        serverTools: [OpenRouterServerTool] = [],
        routing: OpenRouterRouting = OpenRouterRouting(),
        options: OpenRouterOptions = OpenRouterOptions(),
        responseCache: OpenRouterResponseCache? = nil
    ) -> OpenRouterLanguageModel<ContextOptions.ReasoningLevel> {
        // Foundation Models may call the key closure from a task of its own, where the test's key isn't bound.
        let key = APIKey.current
        var model = OpenRouterLanguageModel(
            details,
            serverTools: serverTools,
            routing: routing,
            options: options,
            cacheControl: cacheControl,
            responseCache: responseCache,
            appName: liveAppName,
            apiKey: { key }
        )
        model.fallbacks = fallbacks
        return model
    }
}

/// A tool whose answer the model can't know, so an answer with it shows the tool ran.
struct WeatherTool: Tool {
    let name = "getWeather"
    let description = "Gets the current temperature in a city, in degrees Celsius."

    @Generable
    struct Arguments {
        @Guide(description: "The city's name.")
        var city: String
    }

    func call(arguments: Arguments) async throws -> String {
        "It is 17 degrees in \(arguments.city)."
    }
}

/// A plan with the schema features providers differ on: a nested type, an enum, an exact count, ranges and an
/// optional property.
@Generable
struct Trip {
    @Guide(description: "The city to visit.")
    var city: String

    var season: Season

    @Guide(description: "Three things to do.", .count(3))
    var activities: [Activity]

    @Guide(description: "How many days to stay.", .range(1...14))
    var days: Int

    var note: String?
}

@Generable
enum Season {
    case spring, summer, autumn, winter
}

@Generable
struct Activity {
    var name: String

    @Guide(description: "How many hours it takes.", .range(1...12))
    var hours: Int
}

extension Transcript {
    /// Every tool call in the transcript, in order.
    var toolCalls: [Transcript.ToolCall] {
        flatMap { entry -> [Transcript.ToolCall] in
            if case .toolCalls(let calls) = entry { Array(calls) } else { [] }
        }
    }

    /// The cities of every weather tool call in the transcript, in order.
    func weatherCities() throws -> [String] {
        try toolCalls.filter { $0.toolName == "getWeather" }.map { try $0.arguments.value(String.self, forProperty: "city") }
    }
}

/// The last answer among the entries.
func lastAnswer(in entries: some Sequence<Transcript.Entry>) -> Transcript.Response? {
    entries.compactMap { entry in if case .response(let answer) = entry { answer } else { nil } }.last
}

/// The reasoning entries among the entries, in order.
func reasoningEntries(in entries: some Sequence<Transcript.Entry>) -> [Transcript.Reasoning] {
    entries.compactMap { entry in if case .reasoning(let reasoning) = entry { reasoning } else { nil } }
}

/// The reasoning details stored in a reasoning entry's signature, or none when it has no list of them.
func reasoningDetails(of reasoning: Transcript.Reasoning) throws -> [JSONValue] {
    guard let signature = reasoning.signature, case .array(let details) = try JSONValue(json: signature) else { return [] }
    return details
}

/// The answer's metadata and its usage's, for reading what OpenRouter reported.
func answerMetadata(_ response: LanguageModelSession.Response<some Generable>) -> String {
    let answer = lastAnswer(in: response.transcriptEntries)
    return "Answer: \(answer?.metadata ?? [:])\nUsage: \(response.usage)"
}

/// Attaches a value to the test's results, for reading what a provider returned.
func record(_ value: Any, named name: String) {
    Attachment.record(String(describing: value), named: name)
}

/// Whether an error means the host was briefly unavailable, rather than that the request failed: a rate limit, a
/// timeout, an unavailable or overloaded host, a gateway status, or no host left that serves the model.
func isTransientFailure(_ error: any Error) -> Bool {
    switch error {
    case let error as LanguageModelError:
        switch error {
        case .rateLimited, .timeout: return true
        default: return false
        }
    case let error as OpenRouterError:
        if [OpenRouterError.Code.providerUnavailable, .providerOverloaded].contains(error.code) { return true }
        if let status = error.status, transientStatuses.contains(status) { return true }
        return error.status == 404 && error.message.localizedCaseInsensitiveContains("no endpoints")
    default:
        return false
    }
}

/// The statuses of a host or gateway that's briefly unavailable or slow.
private let transientStatuses: Set<Int> = [408, 502, 503, 504, 524, 529]

/// A trait that cancels a test whose host was briefly unavailable, attaching the error, instead of failing it.
struct SkipsTransientFailures: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }

    func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        testCase == nil ? nil : self
    }

    // Testing declares the requirement without nonisolated(nonsending), so both the method and its closure run
    // concurrently.
    @concurrent func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable @concurrent () async throws -> Void
    ) async throws {
        do {
            try await function()
        } catch let error where isTransientFailure(error) {
            Attachment.record(String(reflecting: error), named: "transient-error.txt")
            try Test.cancel("The host was briefly unavailable: \(error)")
        }
    }
}

extension Trait where Self == SkipsTransientFailures {
    /// Cancels a test whose host was briefly unavailable, instead of failing it.
    static var skipsTransientFailures: Self { Self() }
}
