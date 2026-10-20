import Foundation
import LanguageModels
import Testing

@Suite("Same-host redirects")
struct SameHostRedirectsTests {
    @Test(arguments: [
        ("https://api.example.com/v1/chat", "https://api.example.com/v2/chat", true),
        ("https://api.example.com/v1/chat", "https://evil.example.org/v1/chat", false),
        ("https://api.example.com/v1/chat", "http://api.example.com/v1/chat", false),
        ("https://api.example.com/v1/chat", "https://api.example.com:8443/v1/chat", false),
    ])
    func `a redirect is followed only to the same scheme, host and port`(from: String, to: String, isFollowed: Bool) async throws {
        let original = try #require(URL(string: from))
        let target = try #require(URL(string: to))
        let task = URLSession.shared.dataTask(with: original)
        let response = try #require(HTTPURLResponse(url: original, statusCode: 307, httpVersion: nil, headerFields: nil))

        let followed = await SameHostRedirects().urlSession(
            .shared,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: target)
        )

        #expect((followed != nil) == isFollowed)
    }
}
