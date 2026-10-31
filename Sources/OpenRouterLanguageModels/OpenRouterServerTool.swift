public import Foundation
public import FoundationModels
import LanguageModels

/// A tool that OpenRouter runs for the model while it answers, such as a web search or a call to another model.
///
/// Server tools are a setting of the model, in ``OpenRouterLanguageModel/serverTools``, rather than Foundation Models
/// tools: the app implements nothing, and their calls never reach the session. The model decides when to call one, and
/// OpenRouter runs it and hands the result back to the model, which may call it again before it answers. A request
/// lists them after the session's own tools, in the order given.
///
/// ```swift
/// let model = OpenRouterLanguageModel(
///     .openaiGpt5Mini,
///     serverTools: [.webSearch(maximumResults: 3, allowedDomains: ["swift.org"]), .datetime(timeZone: .current)],
///     auth: .apiKey { try await keyStore.openRouterKey() }
/// )
/// ```
///
/// A web search or web fetch costs extra, on top of the model's tokens, and its engine keeps what it's sent under its
/// own data retention policy; ``OpenRouterWebSearchEngine`` and ``OpenRouterWebFetchEngine`` say which engine runs
/// when and what each costs. The date and time cost nothing and never leave OpenRouter. An advisor or a subagent calls
/// another model, billed at that model's price on top of the model's own tokens, and only the answer it informs reaches
/// the session.
///
/// Two tools are equal when a request sends the same entry for them.
public struct OpenRouterServerTool: Sendable, Hashable {
    /// The tool's type.
    let name: Name

    /// The tool's parameters that are set, in the order a request lists them.
    let parameters: JSONObject

    private init(_ name: Name, parameters: JSONObject) {
        self.name = name
        self.parameters = parameters
    }

    /// Searches the web, so the model can answer with current information and cite the pages it used.
    ///
    /// The answer's response entry lists the cited pages, which ``OpenRouterResponseMetadata/citations`` reads.
    ///
    /// - Parameters:
    ///   - engine: The engine that searches, or `nil` for OpenRouter's default, `auto`: the host's own search when the
    ///     model's host has one, and Exa otherwise.
    ///   - mode: How deep Exa or Parallel searches, or `nil` for the engine's default. Other engines ignore it.
    ///   - maximumResults: The most results of one search, from 1 to 25, or `nil` for OpenRouter's default of 5. The
    ///     hosts' own search ignores it.
    ///   - maximumTotalResults: The most results across all of an answer's searches. Searches past it tell the model
    ///     the limit was reached instead of returning results.
    ///   - maximumSearches: The most searches in one answer. Searches past it return an error to the model instead of
    ///     running. Of the hosts' own search, only Anthropic's takes it.
    ///   - contextSize: How much of each page the model gets, for Exa, Parallel and Perplexity.
    ///   - allowedDomains: The only domains to return results from, such as `"arxiv.org"`. Most engines take either
    ///     this list or `excludedDomains`, not both, and Google's own search takes neither.
    ///   - excludedDomains: Domains never to return results from.
    /// - Returns: The web search.
    public static func webSearch(
        engine: OpenRouterWebSearchEngine? = nil,
        mode: OpenRouterWebSearchMode? = nil,
        maximumResults: Int? = nil,
        maximumTotalResults: Int? = nil,
        maximumSearches: Int? = nil,
        contextSize: OpenRouterSearchContextSize? = nil,
        allowedDomains: [String]? = nil,
        excludedDomains: [String]? = nil
    ) -> Self {
        Self(
            .webSearch,
            parameters: [
                "engine": engine.map { .string($0.rawValue) },
                "mode": mode.map { .string($0.rawValue) },
                "max_results": maximumResults.map(JSONValue.integer),
                "max_total_results": maximumTotalResults.map(JSONValue.integer),
                "max_uses": maximumSearches.map(JSONValue.integer),
                "search_context_size": contextSize.map { .string($0.rawValue) },
                "allowed_domains": allowedDomains.map(domains),
                "excluded_domains": excludedDomains.map(domains),
            ]
        )
    }

    /// Fetches a web page or PDF the model names by its URL, and gives the model its text.
    ///
    /// - Parameters:
    ///   - engine: The engine that fetches, or `nil` for OpenRouter's default, `auto`: the host's own fetch when the
    ///     model's host has one, and Exa otherwise.
    ///   - maximumFetches: The most fetches in one answer. Fetches past it return an error to the model. OpenRouter's
    ///     own fetcher and the hosts' own fetch stop at 50 anyway.
    ///   - maximumContentTokens: The most content of one page, in approximate tokens; longer content is cut short.
    ///     The hosts' own fetch ignores it.
    ///   - allowedDomains: The only domains to fetch from, such as `"docs.example.com"`.
    ///   - excludedDomains: Domains never to fetch from.
    /// - Returns: The web fetch.
    public static func webFetch(
        engine: OpenRouterWebFetchEngine? = nil,
        maximumFetches: Int? = nil,
        maximumContentTokens: Int? = nil,
        allowedDomains: [String]? = nil,
        excludedDomains: [String]? = nil
    ) -> Self {
        Self(
            .webFetch,
            parameters: [
                "engine": engine.map { .string($0.rawValue) },
                "max_uses": maximumFetches.map(JSONValue.integer),
                "max_content_tokens": maximumContentTokens.map(JSONValue.integer),
                "allowed_domains": allowedDomains.map(domains),
                "blocked_domains": excludedDomains.map(domains),
            ]
        )
    }

    /// Tells the model the current date and time.
    ///
    /// - Parameter timeZone: The time zone of the date and time, as a time zone with an IANA identifier such as
    ///   `Europe/Athens`, or `nil` for UTC.
    /// - Returns: The date and time tool.
    public static func datetime(timeZone: TimeZone? = nil) -> Self {
        Self(.datetime, parameters: ["timezone": timeZone.map { .string($0.identifier) }])
    }

    /// Lets the model consult another model, usually a stronger one, for advice while it answers, such as before it
    /// settles on an approach or when it's stuck.
    ///
    /// The model sends the advisor a prompt, and OpenRouter returns the advisor's answer to the model, which writes the
    /// final answer. Each consultation is a request to the advisor model, billed at its price on top of the model's
    /// tokens, and it adds the time the advisor takes. The consultation never reaches the session: the answer's usage
    /// counts it among ``OpenRouterMetadataKey/requestedServerToolCallCount``, and chat completions return neither the
    /// prompt nor the advice. So the advisor can't recall its earlier consultations on later turns; with
    /// `forwardsTranscript`, it reads the whole conversation instead.
    ///
    /// To offer several advisors, list one advisor per model with a `name` each; at most one can go without a name,
    /// and keep their order across a session's requests. A required tool-calling mode doesn't force a consultation,
    /// since `tool_choice` goes out only with the session's own tools.
    ///
    /// - Parameters:
    ///   - model: The advisor model, such as `"~anthropic/claude-opus-latest"`, or `nil` to let the model name one in
    ///     each consultation, or else consult the model itself.
    ///   - name: The name the model knows the advisor by, of 1 to 64 letters, digits, spaces, `_` and `-`, or `nil`
    ///     for the default advisor.
    ///   - instructions: The advisor's instructions, or `nil` for none.
    ///   - forwardsTranscript: Whether the advisor reads the whole conversation, with the model's prompt after it,
    ///     rather than the prompt alone.
    ///   - maximumResponseTokens: The most tokens the advisor generates, reasoning included, or `nil` for its host's
    ///     default.
    ///   - reasoningLevel: How much the advisor reasons, as the nearest effort OpenRouter knows, or `nil` for its
    ///     default. A custom level that OpenRouter doesn't list is left out.
    ///   - maximumReasoningTokens: The most tokens the advisor reasons with, or `nil` for its default.
    ///   - temperature: The advisor's sampling temperature, from 0 to 2, or `nil` for its host's default.
    /// - Returns: The advisor.
    public static func advisor(
        model: OpenRouterModelID? = nil,
        name: String? = nil,
        instructions: String? = nil,
        forwardsTranscript: Bool = false,
        maximumResponseTokens: Int? = nil,
        reasoningLevel: ContextOptions.ReasoningLevel? = nil,
        maximumReasoningTokens: Int? = nil,
        temperature: Double? = nil
    ) -> Self {
        var parameters = modelCall(
            model: model, name: name, instructions: instructions, maximumResponseTokens: maximumResponseTokens,
            reasoningLevel: reasoningLevel, maximumReasoningTokens: maximumReasoningTokens, temperature: temperature)
        parameters["forward_transcript"] = forwardsTranscript ? true : nil
        return Self(.advisor, parameters: parameters)
    }

    /// Lets the model hand a self-contained task to another model, usually a smaller and cheaper one, such as
    /// summarizing a document or drafting boilerplate, and use its outcome while it answers.
    ///
    /// The model describes the task, and OpenRouter returns the worker model's outcome to the model. The worker reads
    /// only that description, never the conversation, and keeps nothing between tasks. Each task is a request to the
    /// worker model, billed at its price on top of the model's tokens, and more when the worker uses server tools. The
    /// task never reaches the session; the answer's usage counts it among
    /// ``OpenRouterMetadataKey/requestedServerToolCallCount``.
    ///
    /// To offer several workers, list one subagent per model with a `name` each; at most one can go without a name,
    /// and keep their order across a session's requests.
    ///
    /// - Parameters:
    ///   - model: The worker model, such as `"~anthropic/claude-haiku-latest"`, or `nil` for the model itself.
    ///   - name: The name the model knows the worker by, of 1 to 64 letters, digits, spaces, `_` and `-`, or `nil`
    ///     for the default worker.
    ///   - instructions: The worker's instructions, or `nil` for none.
    ///   - tools: Server tools the worker can use for a task, such as `.webSearch()`, but no subagent. The session's
    ///     own tools never reach it.
    ///   - maximumToolCalls: The most tool-calling steps the worker takes for one task, from 1 to 25, or `nil` for
    ///     OpenRouter's default.
    ///   - maximumResponseTokens: The most tokens the worker generates, reasoning included, or `nil` for its host's
    ///     default.
    ///   - reasoningLevel: How much the worker reasons, as the nearest effort OpenRouter knows, or `nil` for its
    ///     default. A custom level that OpenRouter doesn't list is left out.
    ///   - maximumReasoningTokens: The most tokens the worker reasons with, or `nil` for its default.
    ///   - temperature: The worker's sampling temperature, from 0 to 2, or `nil` for its host's default.
    /// - Returns: The subagent.
    public static func subagent(
        model: OpenRouterModelID? = nil,
        name: String? = nil,
        instructions: String? = nil,
        tools: [OpenRouterServerTool] = [],
        maximumToolCalls: Int? = nil,
        maximumResponseTokens: Int? = nil,
        reasoningLevel: ContextOptions.ReasoningLevel? = nil,
        maximumReasoningTokens: Int? = nil,
        temperature: Double? = nil
    ) -> Self {
        var parameters = modelCall(
            model: model, name: name, instructions: instructions, maximumResponseTokens: maximumResponseTokens,
            reasoningLevel: reasoningLevel, maximumReasoningTokens: maximumReasoningTokens, temperature: temperature)
        parameters["tools"] = tools.isEmpty ? nil : .array(tools.map(\.json))
        parameters["max_tool_calls"] = maximumToolCalls.map(JSONValue.integer)
        return Self(.subagent, parameters: parameters)
    }
}

extension OpenRouterServerTool {
    /// A server tool's `type` in OpenRouter's API, for each kind of tool that ``OpenRouterServerTool`` builds.
    enum Name: String {
        case webSearch = "openrouter:web_search"
        case webFetch = "openrouter:web_fetch"
        case datetime = "openrouter:datetime"
        case advisor = "openrouter:advisor"
        case subagent = "openrouter:subagent"
    }

    /// The tool's entry in a request's `tools`: its type, and its `parameters` when any is set.
    var json: JSONValue {
        ["type": .string(name.rawValue), "parameters": parameters.members.isEmpty ? nil : .object(parameters)]
    }

    /// Every effort word OpenRouter lists, as levels, for finding the nearest one to a level.
    private static let everyEffort = ContextOptions.ReasoningLevel.effortRanking.map(ContextOptions.ReasoningLevel.custom)

    /// The parameters of a call to another model that an advisor and a subagent share, with the reasoning settings
    /// together under `reasoning`.
    private static func modelCall(
        model: OpenRouterModelID?,
        name: String?,
        instructions: String?,
        maximumResponseTokens: Int?,
        reasoningLevel: ContextOptions.ReasoningLevel?,
        maximumReasoningTokens: Int?,
        temperature: Double?
    ) -> JSONObject {
        let reasoning: JSONObject = [
            "effort": reasoningLevel?.providerEffort(supporting: everyEffort).map(JSONValue.string),
            "max_tokens": maximumReasoningTokens.map(JSONValue.integer),
        ]
        return [
            "name": name.map(JSONValue.string),
            "model": model.map { .string($0.rawValue) },
            "instructions": instructions.map(JSONValue.string),
            "max_completion_tokens": maximumResponseTokens.map(JSONValue.integer),
            "reasoning": reasoning.members.isEmpty ? nil : .object(reasoning),
            "temperature": temperature.map(JSONValue.number),
        ]
    }

    /// A list of domains, as sent, so an empty list still counts as set.
    private static func domains(_ domains: [String]) -> JSONValue {
        .array(domains.map(JSONValue.string))
    }
}
