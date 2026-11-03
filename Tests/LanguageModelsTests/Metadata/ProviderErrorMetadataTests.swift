import Foundation
import FoundationModels
import Testing

@testable import LanguageModels

@Suite("Provider error metadata")
struct ProviderErrorMetadataTests {
    @Test func `every kind of failure reads the provider's facts from its metadata`() {
        var metadata = LanguageModelError.failureMetadata(status: 429, code: "rate_limit_exceeded", provider: "Vendor")
        metadata[LanguageModelMetadataKey.requestID] = "req_1"
        let failures: [LanguageModelError.ProviderFailure] = [
            .contextSizeExceeded(contextSize: 8, tokenCount: 9), .rateLimited(resetDate: nil), .guardrailViolation, .refusal,
            .timeout, .unsupportedContent([]),
        ]

        for failure in failures {
            let facts = LanguageModelError(failure, message: "Failed.", metadata: metadata).providerMetadata

            #expect(facts.status == 429, "\(failure)")
            #expect(facts.errorCode == "rate_limit_exceeded", "\(failure)")
            #expect(facts.provider == "Vendor", "\(failure)")
            #expect(facts.requestID == "req_1", "\(failure)")
        }
    }

    @Test func `an error without the provider's facts reads as none`() {
        let facts = LanguageModelError.timeout(.init(debugDescription: "Timed out.")).providerMetadata

        #expect(facts == ProviderErrorMetadata([:]))
        #expect(facts.status == nil)
        #expect(facts.requestID == nil)
    }
}
