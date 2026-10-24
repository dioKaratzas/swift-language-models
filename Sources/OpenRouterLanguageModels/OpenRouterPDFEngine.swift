public import LanguageModels

/// The engine that reads PDF attachments for a request.
///
/// Without one, OpenRouter passes a PDF to a model that reads PDFs itself, and has `mistral-ocr` read it for any other
/// model. `mistral-ocr` reads scanned pages and images, and costs extra per page, from the account's OpenRouter credits,
/// also with the account's own provider keys. `cloudflare-ai` turns the PDF into text for free. `native` passes the PDF
/// to the model, billed as input tokens, and only models that read PDFs themselves take it.
///
/// An engine other than `native` reads the PDF before the model sees it, also for a model that could read it itself,
/// and the service it uses keeps what it's sent under its own policy.
///
/// Engines are an open vocabulary: any engine OpenRouter lists is valid, with or without a static member.
public struct OpenRouterPDFEngine: ProviderVocabulary {
    /// Free text extraction through Cloudflare Workers AI, as Markdown.
    public static let cloudflareAI: Self = "cloudflare-ai"

    /// Mistral's OCR, for scanned documents and pages with images, at a price per page.
    public static let mistralOCR: Self = "mistral-ocr"

    /// The model's own PDF reading, for models that list file input.
    public static let native: Self = "native"

    /// The engine's name in OpenRouter's API.
    public let rawValue: String

    /// Creates an engine from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"cloudflare-ai"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an engine from a string literal of its name in OpenRouter's API.
    ///
    /// - Parameter value: The name, such as `"cloudflare-ai"`.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// The raw value, so printing a value shows OpenRouter's spelling of it.
    public var description: String { rawValue }
}
