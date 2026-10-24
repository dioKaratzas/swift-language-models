import Foundation
import Testing

@testable import OpenRouterLanguageModels

@Suite("Citations")
struct OpenRouterCitationTests {
    @Test func `a citation built with only its address leaves the rest unknown`() throws {
        let url = try #require(URL(string: "https://swift.org/blog/"))

        let citation = OpenRouterCitation(url: url)

        #expect(citation.url == url)
        #expect(citation.title == nil)
        #expect(citation.excerpt == nil)
        #expect(citation.startIndex == nil)
        #expect(citation.endIndex == nil)
    }

    @Test func `a citation built with every field reads back from an entry's metadata unchanged`() throws {
        let citation = OpenRouterCitation(
            url: try #require(URL(string: "https://swift.org/blog/swift-6.4")), title: "Swift 6.4 Released",
            excerpt: "Swift 6.4 is now available.", startIndex: 0, endIndex: 18)

        #expect(OpenRouterCitation(metadataValue: citation.metadataValue) == citation)
    }
}
