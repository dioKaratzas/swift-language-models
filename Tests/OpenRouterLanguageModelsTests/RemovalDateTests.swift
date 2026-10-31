import Foundation
import FoundationModels
import LanguageModels
import Testing

@testable import OpenRouterLanguageModels

@Suite("Removal date")
struct RemovalDateTests {
    @Test func `a model OpenRouter lists has no removal date`() {
        #expect(fallback("vendor/model").removalDate == nil)
    }

    @Test func `the catalog's removed models carry the day they left and are left out of its lookup by id`() {
        for (id, day) in ModelRemovals.openRouter.dates {
            let id = OpenRouterModelID(rawValue: id)

            #expect(fallback(id).removalDate == day)
            #expect(OpenRouterModel<ContextOptions.ReasoningLevel>(catalogID: id) == nil)
        }
    }
}
