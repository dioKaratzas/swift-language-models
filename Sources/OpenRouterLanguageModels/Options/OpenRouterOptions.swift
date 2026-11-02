import LanguageModels

/// Request settings that only OpenRouter has, beyond Foundation Models' generation options.
///
/// Each sampling setting reaches the model only if the model lists its parameter, such as `frequency_penalty`, so a
/// setting a model doesn't take is left out instead of failing the request. Router settings reach only the router
/// model that reads them. Every setting left `nil` keeps the model's default.
public struct OpenRouterOptions: Sendable, Hashable {
    /// Lowers the chance of a token by how often it already appeared, from -2 to 2.
    public var frequencyPenalty: Double?

    /// Lowers the chance of a token that already appeared at all, from -2 to 2.
    public var presencePenalty: Double?

    /// Scales down the chance of tokens that already appeared; 1 means no penalty.
    public var repetitionPenalty: Double?

    /// Drops tokens whose chance is below this fraction of the most likely token's, from 0 to 1.
    public var minP: Double?

    /// Keeps only tokens with a chance close enough to the most likely token's, from 0 to 1.
    public var topA: Double?

    /// Text that ends the response when the model generates it, up to four sequences.
    public var stopSequences: [String]?

    /// Changes to the chance of specific tokens, by token id, from -100 to 100.
    public var logitBias: [Int: Double]?

    /// How long and detailed the answers are, such as `low` for concise ones.
    public var verbosity: OpenRouterOptions.Verbosity?

    /// The processing tier, such as `flex` or `priority`, which trades speed against price.
    public var serviceTier: OpenRouterServiceTier?

    /// A stable id for the app's end user, such as a hash, so a host can tell users apart for abuse checks.
    public var endUserID: String?

    /// How `openrouter/auto` and `openrouter/auto-beta` pick the model that answers.
    public var autoRouter: OpenRouterOptions.AutoRouter?

    /// How `openrouter/pareto-code` picks the coding model that answers.
    public var paretoRouter: OpenRouterOptions.ParetoRouter?

    /// Whether the model may ask for several of the session's tools in one answer.
    ///
    /// With ``ParallelToolCalls/automatic``, the request leaves the choice to the host. Either other choice reaches
    /// only models that list `parallel_tool_calls`, and with tools, OpenRouter then routes only to hosts that take it.
    /// Calls that arrive in one answer run as one round either way.
    public var parallelToolCalls: ParallelToolCalls

    /// The engine that reads PDF attachments, or `nil` for OpenRouter's default: the model's own reading when it reads
    /// PDFs, and Mistral's OCR, at a price per page, when it doesn't.
    ///
    /// It goes out only with a request that carries a PDF. With ``OpenRouterOptions/PDFEngine/native``, only models that read
    /// PDFs themselves take PDF attachments.
    public var pdfEngine: PDFEngine?

    /// Whether the answer reports how OpenRouter routed the request: the strategy, the endpoints it considered, each
    /// attempt, the edge region, the generation time and the plugins that changed the request or answer.
    ///
    /// The entry that ends the answer carries them under ``OpenRouterMetadataKey``, such as
    /// ``OpenRouterMetadataKey/routingStrategy``. An answer from the response cache never has them.
    public var includesRouterMetadata: Bool

    /// Creates request settings.
    ///
    /// - Parameters:
    ///   - frequencyPenalty: Lowers the chance of a token by how often it already appeared.
    ///   - presencePenalty: Lowers the chance of a token that already appeared at all.
    ///   - repetitionPenalty: Scales down the chance of tokens that already appeared.
    ///   - minP: Drops tokens whose chance is below this fraction of the most likely token's.
    ///   - topA: Keeps only tokens with a chance close enough to the most likely token's.
    ///   - stopSequences: Text that ends the response when the model generates it.
    ///   - logitBias: Changes to the chance of specific tokens, by token id.
    ///   - verbosity: How long and detailed the answers are.
    ///   - serviceTier: The processing tier.
    ///   - endUserID: A stable id for the app's end user.
    ///   - autoRouter: How `openrouter/auto` and `openrouter/auto-beta` pick the model that answers.
    ///   - paretoRouter: How `openrouter/pareto-code` picks the coding model that answers.
    ///   - parallelToolCalls: Whether the model may ask for several of the session's tools in one answer.
    ///   - pdfEngine: The engine that reads PDF attachments, or `nil` for OpenRouter's default.
    ///   - includesRouterMetadata: Whether the answer reports how OpenRouter routed the request.
    public init(
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        repetitionPenalty: Double? = nil,
        minP: Double? = nil,
        topA: Double? = nil,
        stopSequences: [String]? = nil,
        logitBias: [Int: Double]? = nil,
        verbosity: OpenRouterOptions.Verbosity? = nil,
        serviceTier: OpenRouterServiceTier? = nil,
        endUserID: String? = nil,
        autoRouter: OpenRouterOptions.AutoRouter? = nil,
        paretoRouter: OpenRouterOptions.ParetoRouter? = nil,
        parallelToolCalls: ParallelToolCalls = .automatic,
        pdfEngine: PDFEngine? = nil,
        includesRouterMetadata: Bool = false
    ) {
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.repetitionPenalty = repetitionPenalty
        self.minP = minP
        self.topA = topA
        self.stopSequences = stopSequences
        self.logitBias = logitBias
        self.verbosity = verbosity
        self.serviceTier = serviceTier
        self.endUserID = endUserID
        self.autoRouter = autoRouter
        self.paretoRouter = paretoRouter
        self.parallelToolCalls = parallelToolCalls
        self.pdfEngine = pdfEngine
        self.includesRouterMetadata = includesRouterMetadata
    }
}

extension OpenRouterOptions {
    /// Whether a model may ask for several tools in one answer.
    public enum ParallelToolCalls: Sendable, Hashable {
        /// The host's own default, with no `parallel_tool_calls` in the request.
        case automatic

        /// The model may ask for several tools in one answer.
        case allowed

        /// The model asks for at most one tool per answer.
        case disallowed

        /// The `parallel_tool_calls` value, or `nil` to leave it out.
        var json: JSONValue? {
            switch self {
            case .automatic: nil
            case .allowed: true
            case .disallowed: false
            }
        }
    }

    /// The settings that go in the request body as they are: each sampling setting only when every model lists its
    /// parameter, then the service tier and the end user's id.
    ///
    /// - Parameter parameters: The parameters every model lists, which notes each setting left out.
    /// - Returns: The members, in the order the body has them.
    func json(listedIn parameters: inout ListedParameters<OpenRouterParameter>) -> JSONObject {
        [
            "frequency_penalty": parameters.value(of: .frequencyPenalty, frequencyPenalty.map(JSONValue.number)),
            "presence_penalty": parameters.value(of: .presencePenalty, presencePenalty.map(JSONValue.number)),
            "repetition_penalty": parameters.value(of: .repetitionPenalty, repetitionPenalty.map(JSONValue.number)),
            "min_p": parameters.value(of: .minP, minP.map(JSONValue.number)),
            "top_a": parameters.value(of: .topA, topA.map(JSONValue.number)),
            "stop": parameters.value(of: .stop, stopSequences.map { .array($0.map(JSONValue.string)) }),
            "logit_bias": parameters.value(of: .logitBias, logitBias.map(Self.json(logitBias:))),
            "verbosity": parameters.value(of: .verbosity, verbosity.map(\.json)),
            "service_tier": serviceTier.map(\.json),
            "user": endUserID.map(JSONValue.string),
        ]
    }

    /// The logit bias as an object keyed by token id, sorted by key, so it gives the same bytes every time.
    private static func json(logitBias: [Int: Double]) -> JSONValue {
        .object(JSONObject(logitBias.map { .init(key: String($0.key), value: .number($0.value)) }).sortedByKey())
    }
}
