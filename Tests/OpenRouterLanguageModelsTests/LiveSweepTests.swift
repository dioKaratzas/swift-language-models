import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

/// Each vendor's cheapest catalog model through three passes, a tool round trip, guided generation and a reasoning
/// tool loop, to find the models the executor doesn't work with yet. It runs only with `LIVE_SWEEP` set, makes about
/// 120 cases for about ten cents, and checks loosely, since it looks for breakage rather than quality.
///
/// A case whose host was briefly unavailable is cancelled rather than failed. Every case attaches its transcript, the
/// answer's metadata and any error.
@Suite(
    "Live sweep: OpenRouter",
    .tags(.liveSweep),
    .requiresAPIKey("OPENROUTER_API_KEY"),
    .enabled(
        if: ProcessInfo.processInfo.environment["LIVE_SWEEP"]?.isEmpty == false,
        "Set LIVE_SWEEP to sweep each vendor's cheapest model"
    ),
    .timeLimit(.minutes(3))
)
struct LiveSweepTests {
    /// What a case checks, which decides the models it can pick.
    enum Pass: Sendable {
        case toolRoundTrip
        case guidedGeneration
        case reasoningToolLoop

        /// Whether the model takes what the pass sends.
        func admits(_ model: OpenRouterModel<ContextOptions.ReasoningLevel>) -> Bool {
            let parameters = model.supportedParameters
            switch self {
            case .toolRoundTrip: return parameters.contains(.tools)
            case .guidedGeneration: return parameters.contains(.responseFormat) || parameters.contains(.structuredOutputs)
            case .reasoningToolLoop: return parameters.contains(.tools) && model.reasoning != .unsupported
            }
        }
    }

    /// Models known to fail a pass, with why. Their cases run in a known issue that may not show on every run, since
    /// it often depends on the host OpenRouter picks.
    static let knownIssues: [Pass: [OpenRouterModelID: String]] = [
        .toolRoundTrip: [
            "meta-llama/llama-3.1-8b-instruct": "Only Groq and CoreWeave serve its tools, and Groq rejects the call with tool_use_failed."
        ],
        .reasoningToolLoop: [
            "moonshotai/kimi-k2.5": "Kimi K2.5 sometimes sends its final answer only as reasoning, with empty content."
        ],
    ]

    @Test(arguments: models(for: .toolRoundTrip))
    func `a tool round trip brings the tool's value into the answer`(model: LiveModel) async throws {
        try await sweep(model, in: .toolRoundTrip, tools: [WeatherTool()]) { session in
            let response = try await session.respond(to: "How warm is it in Lisbon right now? Use the tool.")

            record(answerMetadata(response), named: "metadata.txt")
            Self.expect(response, calledFor: "Lisbon", cities: try session.transcript.weatherCities(), by: model)
        }
    }

    @Test(arguments: models(for: .guidedGeneration))
    func `a guided answer decodes`(model: LiveModel) async throws {
        try await sweep(model, in: .guidedGeneration) { session in
            let response = try await session.respond(to: "Plan a short trip to Lisbon.", generating: Trip.self)

            record(answerMetadata(response), named: "metadata.txt")
            record(response.content, named: "trip.txt")
            #expect(response.usage.output.totalTokenCount > 0)
            Self.expectAnsweringModel(of: response, is: model)
        }
    }

    @Test(arguments: models(for: .reasoningToolLoop))
    func `reasoning goes back through a tool loop and the next turn`(model: LiveModel) async throws {
        try await sweep(model, in: .reasoningToolLoop, tools: [WeatherTool()]) { session in
            let options = ContextOptions(reasoningLevel: model.reasoningLevel)

            let first = try await session.respond(to: "How warm is it in Lisbon right now? Use the tool.", contextOptions: options)
            record(answerMetadata(first), named: "first-metadata.txt")
            let second = try await session.respond(to: "And in Porto? Use the tool.", contextOptions: options)
            record(answerMetadata(second), named: "second-metadata.txt")

            let cities = try session.transcript.weatherCities()
            Self.expect(first, calledFor: "Lisbon", cities: cities, by: model)
            Self.expect(second, calledFor: "Porto", cities: cities, by: model)
        }
    }

    /// Runs one case in a new session, attaching the transcript and any error. A case whose host was briefly
    /// unavailable is cancelled, and a case of a model known to fail the pass runs in a known issue.
    private func sweep(
        _ model: LiveModel,
        in pass: Pass,
        tools: [any Tool] = [],
        _ body: (LanguageModelSession) async throws -> Void
    ) async throws {
        let session = LanguageModelSession(model: model.languageModel, tools: tools)
        var transientError: (any Error)?
        func attempt() async throws {
            do {
                try await body(session)
            } catch {
                record(error, named: "error.txt")
                guard isTransientFailure(error) else { throw error }
                transientError = error
            }
        }

        if let reason = Self.knownIssues[pass]?[model.details.id] {
            await withKnownIssue(Comment(rawValue: reason), isIntermittent: true) {
                try await attempt()
            }
        } else {
            try await attempt()
        }
        record(session.transcript, named: "transcript.txt")
        if let transientError {
            try Test.cancel("The host was briefly unavailable: \(transientError)")
        }
    }

    /// The loose checks of a turn that should call the weather tool for a city and answer with its value.
    private static func expect(
        _ response: LanguageModelSession.Response<String>,
        calledFor city: String,
        cities: [String],
        by model: LiveModel
    ) {
        #expect(cities.contains { $0.localizedCaseInsensitiveContains(city) }, "No call for \(city): \(cities)")
        #expect(response.content.contains("17"))
        #expect(response.usage.output.totalTokenCount > 0)
        expectAnsweringModel(of: response, is: model)
    }

    /// Checks that the answer names the model, as its id or a dated version of it.
    private static func expectAnsweringModel(of response: LanguageModelSession.Response<some Generable>, is model: LiveModel) {
        let answering = lastAnswer(in: response.transcriptEntries).flatMap { metadataString($0.metadata, OpenRouterMetadataKey.model) }
        #expect(answering?.hasPrefix(model.details.id.rawValue) == true, "Answered by \(answering ?? "an unnamed model")")
    }
}

extension LiveSweepTests {
    /// Each vendor's cheapest model that the pass admits, sorted by id.
    ///
    /// Routers, aliases, free variants and Perplexity's models are left out, which leaves models whose price is what
    /// their tokens cost. So are models without text output, models past their expiration date, and models whose
    /// catalog prices are missing or zero, which a ranking by price can't place. A model ranks by what a case roughly
    /// takes: 500 prompt tokens and 80 completion tokens, and 800 more completion tokens of reasoning when the model
    /// always reasons or the pass asks for reasoning.
    static func models(for pass: Pass) -> [LiveModel] {
        var cheapest: [Substring: (price: Decimal, model: OpenRouterModel<ContextOptions.ReasoningLevel>)] = [:]
        for model in OpenRouterModel.catalogModels where isSweepable(model) && pass.admits(model) {
            guard let price = price(of: model, in: pass) else { continue }
            let vendor = model.id.rawValue.prefix { $0 != "/" }
            if let current = cheapest[vendor], current.price <= price { continue }
            cheapest[vendor] = (price, model)
        }
        return cheapest.values.map(\.model).sorted { $0.id.rawValue < $1.id.rawValue }.map { model in
            LiveModel(model, reasoningLevel: reasoningLevel(for: model))
        }
    }

    private static func isSweepable(_ model: OpenRouterModel<ContextOptions.ReasoningLevel>) -> Bool {
        let id = model.id.rawValue
        let isLeftOut = id.hasPrefix("openrouter/") || id.hasPrefix("~") || id.hasSuffix(":free") || id.hasPrefix("perplexity/")
        let hasExpired = model.expirationDate.map { $0 <= .now } ?? false
        return !isLeftOut && !hasExpired && model.outputModalities.contains(.text)
    }

    /// What a case roughly costs at the catalog's prices, or `nil` when they're missing or zero.
    private static func price(of model: OpenRouterModel<ContextOptions.ReasoningLevel>, in pass: Pass) -> Decimal? {
        guard let pricing = model.pricing, pricing.prompt > 0 || pricing.completion > 0 else { return nil }
        let reasons = model.reasoning == .mandatory || pass == .reasoningToolLoop
        return pricing.prompt * 500 + pricing.completion * (reasons ? 880 : 80)
    }

    /// The lowest effort that still reasons, for a model that takes efforts, and otherwise `.light`, which turns
    /// reasoning on.
    private static func reasoningLevel(for model: OpenRouterModel<ContextOptions.ReasoningLevel>) -> ContextOptions.ReasoningLevel {
        let lowestFirst: [ContextOptions.ReasoningLevel] = [.low, .medium, .minimal, .high, .xhigh, .max]
        return lowestFirst.first { model.reasoningEfforts.contains($0) } ?? .light
    }
}
