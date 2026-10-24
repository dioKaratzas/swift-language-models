public import Foundation
public import FoundationModels

/// A web page that an answer cites, found by the ``OpenRouterServerTool`` web search.
///
/// The response entry of an answer that cites pages lists them in its metadata, under
/// ``OpenRouterMetadataKey/citations``, and `Transcript.Response.openRouterCitations` reads them:
///
/// ```swift
/// let model = OpenRouterLanguageModel(.openaiGpt5Mini, serverTools: [.webSearch()], apiKey: { try await keyStore.openRouterKey() })
/// let response = try await LanguageModelSession(model: model).respond(to: "What changed in Swift this year?")
/// for case .response(let answer) in response.transcriptEntries {
///     for citation in answer.openRouterCitations {
///         print(citation.title ?? citation.url.absoluteString)
///     }
/// }
/// ```
public struct OpenRouterCitation: Sendable, Hashable {
    /// The page's address.
    public let url: URL

    /// The page's title, when the search reported one.
    public let title: String?

    /// Text from the page that the search returned to the model, such as Exa's excerpts, which `[...]` separates
    /// when they come from different parts of the page.
    public let excerpt: String?

    /// Where the text that cites the page starts in the answer's text, as an offset, when the host reported it.
    public let startIndex: Int?

    /// Where the text that cites the page ends in the answer's text, as an offset, when the host reported it.
    public let endIndex: Int?
}

extension OpenRouterCitation {
    /// The citation as a value of an entry's metadata.
    var metadataValue: GeneratedContent {
        GeneratedContent(properties: [
            Field.url: url.absoluteString,
            Field.title: title,
            Field.excerpt: excerpt,
            Field.startIndex: startIndex,
            Field.endIndex: endIndex,
        ])
    }

    /// A citation read back from an entry's metadata, or `nil` when the value has no valid URL.
    init?(metadataValue content: GeneratedContent) {
        guard let address = try? content.value(String.self, forProperty: Field.url), let url = URL(string: address) else {
            return nil
        }
        self.init(
            url: url,
            title: try? content.value(String?.self, forProperty: Field.title),
            excerpt: try? content.value(String?.self, forProperty: Field.excerpt),
            startIndex: try? content.value(Int?.self, forProperty: Field.startIndex),
            endIndex: try? content.value(Int?.self, forProperty: Field.endIndex)
        )
    }

    /// The names of a citation's fields in an entry's metadata.
    private enum Field {
        static let url = "url"
        static let title = "title"
        static let excerpt = "excerpt"
        static let startIndex = "startIndex"
        static let endIndex = "endIndex"
    }
}

extension Transcript.Response {
    /// The web pages the answer cites, in the order OpenRouter listed them.
    ///
    /// They come from the ``OpenRouterServerTool`` web search. The list is empty for an answer that cites nothing.
    /// ``OpenRouterMetadataKey/citations`` is a shared key, so another language model's answer reads too when its
    /// citations have the same fields.
    public var openRouterCitations: [OpenRouterCitation] {
        guard case .array(let values)? = metadata[OpenRouterMetadataKey.citations]?.kind else { return [] }
        return values.compactMap(OpenRouterCitation.init(metadataValue:))
    }
}
