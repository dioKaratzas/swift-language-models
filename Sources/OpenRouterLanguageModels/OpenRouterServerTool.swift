public import Foundation
import LanguageModels

/// A tool that OpenRouter runs for the model while it answers, such as a web search.
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
///     apiKey: { try await keyStore.openRouterKey() }
/// )
/// ```
///
/// A web search or web fetch costs extra, on top of the model's tokens, and its engine keeps what it's sent under its
/// own data retention policy; ``OpenRouterWebSearchEngine`` and ``OpenRouterWebFetchEngine`` say which engine runs
/// when and what each costs. The date and time cost nothing and never leave OpenRouter.
public enum OpenRouterServerTool: Sendable, Hashable {
    /// Searches the web, so the model can answer with current information and cite the pages it used.
    ///
    /// The answer's response entry lists the cited pages, which `Transcript.Response.openRouterCitations` reads.
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
    case webSearch(
        engine: OpenRouterWebSearchEngine? = nil,
        mode: OpenRouterWebSearchMode? = nil,
        maximumResults: Int? = nil,
        maximumTotalResults: Int? = nil,
        maximumSearches: Int? = nil,
        contextSize: OpenRouterSearchContextSize? = nil,
        allowedDomains: [String]? = nil,
        excludedDomains: [String]? = nil
    )

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
    case webFetch(
        engine: OpenRouterWebFetchEngine? = nil,
        maximumFetches: Int? = nil,
        maximumContentTokens: Int? = nil,
        allowedDomains: [String]? = nil,
        excludedDomains: [String]? = nil
    )

    /// Tells the model the current date and time.
    ///
    /// - Parameter timeZone: The time zone of the date and time, as a time zone with an IANA identifier such as
    ///   `Europe/Athens`, or `nil` for UTC.
    case datetime(timeZone: TimeZone? = nil)
}

extension OpenRouterServerTool {
    /// A server tool's `type` in OpenRouter's API.
    struct Name: ProviderVocabulary {
        static let webSearch: Self = "openrouter:web_search"
        static let webFetch: Self = "openrouter:web_fetch"
        static let datetime: Self = "openrouter:datetime"

        let rawValue: String
    }

    /// The tool's entry in a request's `tools`: its type, and its `parameters` when any is set.
    var json: JSONValue {
        let name: Name
        let parameters: JSONObject
        switch self {
        case .webSearch(
            let engine, let mode, let maximumResults, let maximumTotalResults, let maximumSearches, let contextSize,
            let allowedDomains, let excludedDomains):
            name = .webSearch
            parameters = [
                "engine": engine.map { .string($0.rawValue) },
                "mode": mode.map { .string($0.rawValue) },
                "max_results": maximumResults.map(JSONValue.integer),
                "max_total_results": maximumTotalResults.map(JSONValue.integer),
                "max_uses": maximumSearches.map(JSONValue.integer),
                "search_context_size": contextSize.map { .string($0.rawValue) },
                "allowed_domains": allowedDomains.map(Self.domains),
                "excluded_domains": excludedDomains.map(Self.domains),
            ]
        case .webFetch(let engine, let maximumFetches, let maximumContentTokens, let allowedDomains, let excludedDomains):
            name = .webFetch
            parameters = [
                "engine": engine.map { .string($0.rawValue) },
                "max_uses": maximumFetches.map(JSONValue.integer),
                "max_content_tokens": maximumContentTokens.map(JSONValue.integer),
                "allowed_domains": allowedDomains.map(Self.domains),
                "blocked_domains": excludedDomains.map(Self.domains),
            ]
        case .datetime(let timeZone):
            name = .datetime
            parameters = ["timezone": timeZone.map { .string($0.identifier) }]
        }
        return ["type": .string(name.rawValue), "parameters": parameters.members.isEmpty ? nil : .object(parameters)]
    }

    /// A list of domains, as sent, so an empty list still counts as set.
    private static func domains(_ domains: [String]) -> JSONValue {
        .array(domains.map(JSONValue.string))
    }
}
