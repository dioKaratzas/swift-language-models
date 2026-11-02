public import LanguageModels

/// A plugin that OpenRouter runs on a request or its answer, by its id in the request's `plugins` and in the router's
/// report.
///
/// The package sends the plugins it needs from the model's settings, such as a router's settings or the engine that
/// reads PDFs, and ``OpenRouterResponseMetadata/PipelineStage/plugin`` names a plugin that ran. Plugins are an open
/// vocabulary: any plugin OpenRouter reports is valid, with or without a static member.
public struct OpenRouterPlugin: ProviderVocabulary {
    /// The Auto Router's settings, which ``OpenRouterOptions/autoRouter`` holds.
    public static let autoRouter: Self = "auto-router"

    /// The beta Auto Router's settings, which ``OpenRouterOptions/autoRouter`` also holds.
    public static let autoBetaRouter: Self = "auto-beta-router"

    /// Context compression, which drops the middle of a transcript that doesn't fit. Requests turn it off.
    public static let contextCompression: Self = "context-compression"

    /// The engine that reads PDF attachments, which ``OpenRouterOptions/pdfEngine`` picks.
    public static let fileParser: Self = "file-parser"

    /// The Pareto Code router's settings, which ``OpenRouterOptions/paretoRouter`` holds.
    public static let paretoRouter: Self = "pareto-router"

    /// The plugin's id in OpenRouter's API.
    public let rawValue: String

    /// Creates a plugin from its id in OpenRouter's API.
    ///
    /// - Parameter rawValue: The id, such as `"file-parser"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
