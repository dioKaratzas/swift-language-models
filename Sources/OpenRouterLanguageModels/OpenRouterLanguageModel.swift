public import Foundation
public import FoundationModels
public import LanguageModels

/// A model on OpenRouter, for Foundation Models sessions.
///
/// Pass a model from the catalog, and the API key as a closure that's read on every request:
///
/// ```swift
/// let model = OpenRouterLanguageModel(.anthropicClaudeSonnet4_6, apiKey: { try await keyStore.openRouterKey() })
/// let session = LanguageModelSession(model: model, instructions: "Plan the week's meals.")
/// ```
///
/// Everything else is Foundation Models: prompts, tools, guided generation, profiles, reasoning levels and
/// generation options. A request sends only the parameters the model lists, so a setting the model doesn't take is
/// left out. Required tool calls are the exception: only `tool_choice` makes a model call a tool, so with
/// `toolCallingMode` set to `.required`, a request throws `LanguageModelError.unsupportedCapability` before sending
/// anything when the model or a fallback doesn't list it, as Amazon's Nova models don't.
///
/// ## Keys
///
/// Never ship an OpenRouter key inside an app, where anyone can extract it. Instead:
///
/// - Let the person enter their own key, keep it in the Keychain, and return it from `apiKey`. A Keychain read
///   blocks, so do it away from the main actor.
/// - During development, read it from an environment variable.
/// - In production, send requests through your own server with `baseURL`, and return a short-lived token for that
///   server from `apiKey`. Requests follow redirects only to the same host, so the token never reaches another one.
///
/// ## Attachments
///
/// Prompts and tool outputs carry images, and from iOS 27.2 and macOS 27.2 data attachments too: PDFs, audio, video
/// and text. A label goes before its attachment as text, so the model can name it, as an `ImageReference` does:
///
/// ```swift
/// let response = try await session.respond {
///     "What did I eat?"
///     Attachment(receipt).label("receipt")
/// }
/// ```
///
/// - An image goes as a JPEG, drawn upright from its orientation, on white, and scaled down so that its longer side is
///   at most 2,048 pixels. Only its pixels leave the device, never metadata such as where a photo was taken. An image
///   at a web address goes as that address. An image data attachment, such as a PNG or HEIC file, goes the same way.
/// - A PDF goes as a file. A model that reads PDFs gets it as it is; for any other model OpenRouter reads it first,
///   with Mistral's OCR at a price per page, unless ``OpenRouterOptions/pdfEngine`` picks another engine, such as the
///   free ``OpenRouterPDFEngine/cloudflareAI``.
/// - Audio in WAV, MP3, AIFF, AAC, FLAC, Ogg or MPEG-4 goes with its format, video in MPEG-4, MPEG, QuickTime or WebM
///   goes as data, and plain text goes as text.
/// - When the model or a fallback doesn't take an attachment, a request throws before sending anything, as Foundation
///   Models does: `LanguageModelError.unsupportedCapability` with `.vision` for an image attachment, and
///   `LanguageModelError.unsupportedTranscriptContent` for a data attachment, an image file included. Instructions
///   become a `system` message, which takes only text, so an attachment there throws `unsupportedTranscriptContent`
///   too.
/// - Each request sends the whole transcript, so an attachment goes, and is billed as input, again with every later
///   request of the session. It's the same bytes each time, so a provider that caches prompts bills the repeat at its
///   cached price. An attachment on an answer isn't sent back.
///
/// A model that generates images, such as `.googleGemini2_5FlashImage`, is asked for images and text when every model
/// of the request generates images and the request has no response schema. Each image it generates becomes a data entry
/// of its own, of the kind its data names, such as PNG. Generated images stay in the transcript but aren't sent back,
/// so they aren't billed again; to build on one, attach it to a later prompt. Data entries need iOS 27.2 and macOS
/// 27.2; before them, images aren't asked for.
///
/// ## Response metadata
///
/// The entry that ends an answer carries facts about the answer: the model that answered, its host, OpenRouter's
/// generation id, why the answer ended, the service tier that served it, and whether the response cache served it.
/// The answer's usage carries what it cost and counted: its cost and, when OpenRouter reports them, the host's charge
/// and its parts, whether the account's own key paid the host, and the server tools' calls. ``OpenRouterMetadataKey``
/// names the keys. An answer cut off at its token limit doesn't throw; its finish reason is `length`:
///
/// ```swift
/// let response = try await session.respond(to: "Plan the week.", options: GenerationOptions(maximumResponseTokens: 200))
/// if case .response(let answer)? = response.transcriptEntries.last,
///     answer.metadata[OpenRouterMetadataKey.finishReason]?.kind == .string("length")
/// {
///     // The plan was cut short.
/// }
/// ```
///
/// With ``OpenRouterOptions/includesRouterMetadata``, the entry also reports how OpenRouter routed the request: the
/// strategy, the endpoints it could pick from, each attempt, the edge region, how long the host took, and the plugins
/// that changed the request or the answer.
///
/// ## Response cache
///
/// With ``responseCache`` set, OpenRouter keeps each answer for a while, and answers a request that repeats one, with
/// the same API key and body, with the kept answer, at no cost and without reaching a host:
///
/// ```swift
/// var model = OpenRouterLanguageModel(.openaiGpt5Mini, apiKey: { try await keyStore.openRouterKey() })
/// model.responseCache = OpenRouterResponseCache(timeToLive: .seconds(600))
/// ```
///
/// A hit repeats the kept answer whatever the temperature, sampling mode or seed, so it's the same answer every time
/// until it expires or ``OpenRouterResponseCache/refreshes`` replaces it. Each request sends the transcript so far, so
/// requests repeat one another when their sessions went the same way, such as new sessions with the same instructions
/// and prompt. The session id goes in a header while the cache is on, since the cache compares the whole body, and a
/// session's requests still reach the host that cached its prompt. The entry says whether the cache served the
/// answer, under ``OpenRouterMetadataKey/responseCacheHit``.
///
/// ## Server tools
///
/// Server tools are tools that OpenRouter runs for the model while it answers: a web search, a web page fetch, the
/// current date and time, an advisor model to consult and a subagent model to hand tasks to. The app implements
/// nothing; the model calls them as it needs, and only its answer reaches the session:
///
/// ```swift
/// let model = OpenRouterLanguageModel(
///     .openaiGpt5Mini,
///     serverTools: [.webSearch(maximumSearches: 3), .datetime(timeZone: .current)],
///     apiKey: { try await keyStore.openRouterKey() }
/// )
/// let response = try await LanguageModelSession(model: model).respond(to: "What's on in Athens this weekend?")
/// ```
///
/// - Searches and fetches cost extra, on top of the model's tokens. Web search engines charge per search, and
///   Firecrawl also per result, from the account's OpenRouter credits; a host's own search or fetch is billed at the
///   host's price. The date and time are free.
/// - An advisor or a subagent is a request to another model, billed at that model's price. Chat completions return
///   neither the model's request nor the other model's answer, so an advisor can't recall earlier consultations.
/// - The engine decides who sees what the model searches for and fetches. By default the host's own search or fetch
///   runs when the model's host has one, and Exa otherwise; `engine` picks another, such as
///   ``OpenRouterWebSearchEngine/perplexity`` or OpenRouter's own fetcher, ``OpenRouterWebFetchEngine/openrouter``.
/// - Data retention depends on the engine. With zero data retention enforced on the account, OpenRouter rejects
///   Firecrawl, while Exa, Parallel, Perplexity and the hosts' own search keep what they're sent under their own
///   policies. ``OpenRouterRouting/requiresZeroDataRetention`` picks the hosts of the model, not the engines.
///
/// Server tools are sent with the session's own tools, after them, and only when the model and every fallback take
/// tools; otherwise a request throws `LanguageModelError.unsupportedCapability` before sending anything. They count as
/// tools, so a request with them asks for hosts that honor every parameter, unless
/// ``OpenRouterRouting/requiresParameters`` says otherwise. A tool-calling mode concerns only the session's tools:
/// `tool_choice` goes out only with them, although a server-tool call can meet `.required`, and `.disallowed` leaves
/// out the server tools too.
///
/// The pages a web search answer cites are on its response entry, as ``OpenRouterCitation`` values that
/// `Transcript.Response.openRouterCitations` reads. OpenRouter's record of a server-tool call, when it sends one, is
/// part of the answer's reasoning details, and goes back on later turns with them unless a fallback wrote the answer.
///
/// ## Fallbacks
///
/// Fallbacks are models that OpenRouter tries in order when the model fails, whatever the error: a prompt too long
/// for its context, a moderation flag, a rate limit or downtime. Catalog models of any effort type can follow the
/// model:
///
/// ```swift
/// let model = OpenRouterLanguageModel(
///     .anthropicClaudeSonnet4_6,
///     fallbacks: .openaiGpt5Nano, .googleGemini3_1FlashLite,
///     apiKey: { try await keyStore.openRouterKey() }
/// )
/// ```
///
/// Any of the models may answer, so a request asks only for what all of them support:
///
/// - `details` describes the first model, but `capabilities`, `supportsDataAttachmentType(_:)` and
///   `supportsDataEntryType(_:)` answer for the whole list. Tool calling, guided generation, reasoning and images work
///   only when every model supports them, and an attachment or data kind only when every model takes it.
/// - A setting is sent only when every model lists its parameter, and the token limit is the smallest of their limits.
///   Structured outputs are used only when every model takes them, otherwise JSON mode when every model takes that.
/// - A reasoning level becomes the nearest effort that every model accepts. When they share none, the request only
///   turns reasoning on or off, and it doesn't turn reasoning off when any model always reasons.
/// - A schema goes in portable form, with its constraints in descriptions, when any of the models is Anthropic's.
/// - The routing applies to every model, so a ``OpenRouterRouting/variant`` suffixes each of their ids.
/// - A context that's too long is reported with the smallest context size of the models.
///
/// The answer's ``OpenRouterMetadataKey/model`` names the model that answered, and the request is billed at that
/// model's price. That holds for a `:free` model too: when it falls back to a paid model, the request is billed at the
/// paid model's price, so list only `:free` models to keep requests free.
///
/// Reasoning goes back on later turns only to the model that wrote it. Each request tries the first model again, so
/// the reasoning of an answer that a fallback wrote is left out of later requests.
public struct OpenRouterLanguageModel<Effort: ModelEffort>: DetailedLanguageModel {
    /// What OpenRouter reports about the model, the first one a request tries.
    public let details: OpenRouterModel<Effort>

    /// The models to try in order when the model fails, with their efforts in their open form.
    ///
    /// A request lists them after the model, and OpenRouter moves on to the next one on any error. Set them on the
    /// model's initializer to list catalog models of any effort type, or here for models picked at runtime.
    public var fallbacks: [OpenRouterModel<ContextOptions.ReasoningLevel>]

    /// Tools that OpenRouter runs for the model while it answers, such as a web search, next to the session's own
    /// tools.
    ///
    /// A request sends them unless its generation options disallow tool calls, and throws
    /// `LanguageModelError.unsupportedCapability` before sending anything when the model or a fallback doesn't take
    /// tools.
    public var serverTools: [OpenRouterServerTool]

    /// Which of the model's hosts OpenRouter may use.
    public var routing: OpenRouterRouting

    /// Request settings that only OpenRouter has.
    public var options: OpenRouterOptions

    /// How long marked prompts stay cached, or `nil` to send no cache markers.
    public var cacheControl: OpenRouterCacheControl?

    /// OpenRouter's response cache, which answers a repeated request with its earlier answer at no cost, or `nil` to
    /// leave it off.
    public var responseCache: OpenRouterResponseCache?

    /// The session that sends requests.
    let session: URLSession

    /// Returns the API key, on every request.
    let apiKey: @Sendable () async throws -> String

    /// Where requests go, how they name the app, and how long they wait.
    public let executorConfiguration: Executor.Configuration

    /// Creates a model.
    ///
    /// - Parameters:
    ///   - details: The model, usually from the catalog, such as `.anthropicClaudeSonnet4_6`.
    ///   - fallbacks: The models to try in order when the model fails, such as `.openaiGpt5Nano, .googleGemini3_1FlashLite`.
    ///     Each can have its own effort type.
    ///   - serverTools: Tools that OpenRouter runs for the model while it answers, such as `.webSearch()`.
    ///   - routing: Which of the model's hosts OpenRouter may use.
    ///   - options: Request settings that only OpenRouter has.
    ///   - cacheControl: How long marked prompts stay cached. Providers that cache only marked prompts, such as
    ///     Anthropic, cache nothing without it.
    ///   - responseCache: OpenRouter's response cache, which answers a repeated request with its earlier answer at no
    ///     cost, or `nil` to leave it off.
    ///   - appName: The app's name, shown in OpenRouter's rankings.
    ///   - appURL: The app's website, which OpenRouter's rankings link to.
    ///   - appCategories: Up to two of OpenRouter's marketplace categories for the app, such as `.cliAgent`. Any after
    ///     the second are left out.
    ///   - hidesApp: Whether the app OpenRouter creates for `appURL` stays out of its public rankings and marketplace,
    ///     while its usage still shows in the account's analytics. It applies only to the request that creates the app,
    ///     so it can't hide or show an app that already exists.
    ///   - baseURL: Where OpenRouter's API lives, for a proxy; `nil` for OpenRouter itself.
    ///   - session: The session that sends requests.
    ///   - idleTimeout: The longest time to wait for the next data, from sending the request to the end of the answer,
    ///     or `nil` for the session's own timeout. OpenRouter sends keep-alive comments while a model thinks, so this
    ///     doesn't limit a long answer.
    ///   - apiKey: Returns the OpenRouter API key, or a token for the server at `baseURL`. It's called for every
    ///     request and never stored.
    public init<each FallbackEffort: ModelEffort>(
        _ details: OpenRouterModel<Effort>,
        fallbacks: repeat OpenRouterModel<each FallbackEffort>,
        serverTools: [OpenRouterServerTool] = [],
        routing: OpenRouterRouting = OpenRouterRouting(),
        options: OpenRouterOptions = OpenRouterOptions(),
        cacheControl: OpenRouterCacheControl? = nil,
        responseCache: OpenRouterResponseCache? = nil,
        appName: String? = nil,
        appURL: URL? = nil,
        appCategories: [OpenRouterAppCategory] = [],
        hidesApp: Bool = false,
        baseURL: URL? = nil,
        session: URLSession = .shared,
        idleTimeout: Duration? = nil,
        apiKey: @escaping @Sendable () async throws -> String
    ) {
        var bridgedFallbacks: [OpenRouterModel<ContextOptions.ReasoningLevel>] = []
        for fallback in repeat each fallbacks {
            bridgedFallbacks.append(OpenRouterModel(fallback))
        }
        self.init(
            details: details,
            fallbacks: bridgedFallbacks,
            serverTools: serverTools,
            routing: routing,
            options: options,
            cacheControl: cacheControl,
            responseCache: responseCache,
            session: session,
            apiKey: apiKey,
            configuration: Executor.Configuration(
                baseURL: baseURL,
                appName: appName,
                appURL: appURL,
                appCategories: appCategories,
                hidesApp: hidesApp,
                idleTimeout: idleTimeout
            )
        )
    }

    init(
        details: OpenRouterModel<Effort>,
        fallbacks: [OpenRouterModel<ContextOptions.ReasoningLevel>],
        serverTools: [OpenRouterServerTool],
        routing: OpenRouterRouting,
        options: OpenRouterOptions,
        cacheControl: OpenRouterCacheControl?,
        responseCache: OpenRouterResponseCache?,
        session: URLSession,
        apiKey: @escaping @Sendable () async throws -> String,
        configuration: Executor.Configuration
    ) {
        self.details = details
        self.fallbacks = fallbacks
        self.serverTools = serverTools
        self.routing = routing
        self.options = options
        self.cacheControl = cacheControl
        self.responseCache = responseCache
        self.session = session
        self.apiKey = apiKey
        executorConfiguration = configuration
    }
}

extension OpenRouterLanguageModel where Effort == ContextOptions.ReasoningLevel {
    /// The same model with its efforts in their open form, so models with different effort types fit in one list.
    ///
    /// - Parameter typed: A model created from the catalog.
    public init(_ typed: OpenRouterLanguageModel<some ModelEffort>) {
        self.init(
            details: OpenRouterModel(typed.details),
            fallbacks: typed.fallbacks,
            serverTools: typed.serverTools,
            routing: typed.routing,
            options: typed.options,
            cacheControl: typed.cacheControl,
            responseCache: typed.responseCache,
            session: typed.session,
            apiKey: typed.apiKey,
            configuration: Executor.Configuration(typed.executorConfiguration)
        )
    }
}
