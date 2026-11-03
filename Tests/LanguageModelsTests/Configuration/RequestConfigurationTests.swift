import Foundation
import LanguageModels
import Testing

@Suite("Request configuration")
struct RequestConfigurationTests {
    @Test func `the standard retries are two, from half a second, with a server wait of up to 2 minutes`() {
        #expect(RequestRetries.standard == RequestRetries(limit: 2, initialDelay: .milliseconds(500), longestServerWait: .seconds(120)))
        #expect(RequestRetries.disabled.limit == 0)
    }

    @Test func `the policy retries up to the limit, then fails`() throws {
        let policy = RequestRetries(limit: 1, initialDelay: .zero).policy(statuses: { $0 == 503 })

        #expect(policy.retry(1, status: 503, response: nil)?.wait == .zero)
        #expect(policy.retry(2, status: 503, response: nil)?.wait == nil)
        #expect(policy.retry(1, status: 400, response: nil)?.wait == nil)
    }

    @Test func `the policy's first wait is the initial delay, cut by up to a quarter, and doubles after it`() throws {
        let policy = RequestRetries(limit: 3, initialDelay: .seconds(1)).policy(statuses: { _ in true })

        let first = try #require(policy.retry(1, status: 503, response: nil)).wait
        let second = try #require(policy.retry(2, status: 503, response: nil)).wait
        #expect(first >= .milliseconds(750) && first <= .seconds(1))
        #expect(second >= .milliseconds(1_500) && second <= .seconds(2))
    }

    @Test func `a server wait past the longest one fails at once, and a shorter one is waited`() throws {
        let policy = RequestRetries(longestServerWait: .seconds(5)).policy(statuses: { _ in true })
        let url = try #require(URL(string: "https://example.com"))

        let long = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: ["Retry-After": "6"])
        let short = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: ["Retry-After": "5"])
        #expect(policy.retry(1, status: 503, response: long)?.wait == nil)
        #expect(policy.retry(1, status: 503, response: short)?.wait == .seconds(5))
    }

    @Test func `negative retry settings count as zero`() throws {
        let policy = RequestRetries(limit: -3, initialDelay: .seconds(-1), longestServerWait: .seconds(-1)).policy(statuses: { _ in true })

        #expect(policy.retries == 0)
        #expect(policy.retry(1, status: 503, response: nil)?.wait == nil)
    }

    @Test(arguments: [(2_048, 0.85, 2_048, 0.85), (0, -1, 1, 0), (-5, 2, 1, 1), (512, .nan, 512, 0.85)])
    func `image settings outside their range count as the nearest valid value`(
        side: Int, quality: Double, encodedSide: Int, encodedQuality: Double
    ) {
        let encoding = ImageEncoding(maximumSide: side, quality: quality)

        #expect(encoding.encodedMaximumSide == encodedSide)
        #expect(encoding.encodedQuality == encodedQuality)
    }

    @Test func `the standard image encoding keeps 2,048 pixels at a quality of 0.85`() {
        #expect(ImageEncoding.standard == ImageEncoding(maximumSide: 2_048, quality: 0.85))
    }
}
