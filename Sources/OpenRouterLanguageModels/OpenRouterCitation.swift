public import Foundation
import FoundationModels

/// A web page that an answer cites, found by the ``OpenRouterServerTool`` web search.
///
/// The response entry of an answer that cites pages lists them in its metadata, under
/// ``OpenRouterMetadataKey/citations``, and ``OpenRouterResponseMetadata/citations`` reads them:
///
/// ```swift
/// let model = OpenRouterLanguageModel(.openaiGpt5Mini, serverTools: [.webSearch()], apiKey: { try await keyStore.openRouterKey() })
/// let response = try await LanguageModelSession(model: model).respond(to: "What changed in Swift this year?")
/// for case .response(let answer) in response.transcriptEntries {
///     for citation in answer.openRouter.citations {
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
    ///
    /// OpenRouter passes on the host's offset as an integer without saying what it counts, and its SDKs and the AI SDK
    /// provider hand it on unchanged, so whether it counts characters, UTF-16 code units or bytes isn't documented.
    /// Check that it falls within the text before using it.
    public let startIndex: Int?

    /// Where the text that cites the page ends in the answer's text, as an offset in the same unit as
    /// ``startIndex``, when the host reported it.
    ///
    /// Whether the offset is that of the last cited character or the one after it isn't documented either.
    public let endIndex: Int?

    /// Creates a citation, such as for a preview or a test.
    ///
    /// - Parameters:
    ///   - url: The page's address.
    ///   - title: The page's title.
    ///   - excerpt: Text from the page that the search returned to the model.
    ///   - startIndex: Where the text that cites the page starts in the answer's text.
    ///   - endIndex: Where the text that cites the page ends in the answer's text.
    public init(url: URL, title: String? = nil, excerpt: String? = nil, startIndex: Int? = nil, endIndex: Int? = nil) {
        self.url = url
        self.title = title
        self.excerpt = excerpt
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
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
