import Foundation
import Testing

@testable import ModelCatalogGenerator

@Suite("Catalog day")
struct CatalogDayTests {
    @Test func `a day written as yyyy-MM-dd starts at midnight UTC`() throws {
        // Through a variable, because a literal argument would make the tests' literal day instead.
        let text = "2026-12-31"

        let day = try #require(CatalogDay(text))

        #expect(day.start == Date(timeIntervalSince1970: 1_798_675_200))
        #expect(day.description == "2026-12-31")
    }

    @Test(arguments: ["2026-13-01", "2026-02-30", "2026-2-3", "2026-12-31T00:00:00Z", "2026-12-31 ", "31/12/2026", ""])
    func `text that isn't a real day written as yyyy-MM-dd gives nil`(text: String) {
        #expect(CatalogDay(text) == nil)
    }

    @Test(arguments: [(1_798_675_200, "2026-12-31"), (1_798_761_599, "2026-12-31"), (1_798_675_199, "2026-12-30")])
    func `a moment falls on its day in UTC`(secondsSince1970: TimeInterval, day: CatalogDay) {
        #expect(CatalogDay(containing: Date(timeIntervalSince1970: secondsSince1970)) == day)
    }

    @Test func `a day is stored as its text, and text that isn't a day doesn't decode`() throws {
        #expect(try CatalogJSON.encoded(["2026-12-31"] as [CatalogDay]) == "[\n  \"2026-12-31\"\n]\n")
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CatalogDay.self, from: Data(#""2026-02-30""#.utf8))
        }
    }
}
