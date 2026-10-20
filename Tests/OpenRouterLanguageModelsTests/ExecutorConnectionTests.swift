import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: connection failures")
struct ExecutorConnectionTests {
    /// What a failed connection surfaces as.
    enum Outcome: Sendable {
        case connectionFailed
        case timeout
        case cancellation

        func matches(_ error: (any Error)?) -> Bool {
            switch self {
            case .connectionFailed:
                guard let error = error as? OpenRouterError else { return false }
                return error.code == .connectionFailed && error.status == nil
            case .timeout:
                guard case .timeout? = error as? LanguageModelError else { return false }
                return true
            case .cancellation:
                return error is CancellationError
            }
        }
    }

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, Outcome.connectionFailed),
        (.cannotFindHost, .connectionFailed),
        (.cannotConnectToHost, .connectionFailed),
        (.secureConnectionFailed, .connectionFailed),
        (.timedOut, .timeout),
        (.cancelled, .cancellation),
    ])
    func `a connection that fails before a response throws the matching error, without a retry`(code: URLError.Code, outcome: Outcome)
        async throws
    {
        let stub = HTTPStub(.failure(URLError(code)), events(text("Hi"), done()))

        let error = await #expect(throws: (any Error).self) { try await respond(stub) }

        #expect(outcome.matches(error), "Got \(String(describing: error))")
        #expect(stub.requests.count == 1)
    }

    @Test(arguments: [(URLError.Code.networkConnectionLost, Outcome.connectionFailed), (.timedOut, .timeout)])
    func `a connection that drops mid-stream throws the matching error`(code: URLError.Code, outcome: Outcome) async throws {
        let stub = HTTPStub(unfinishedEvents(text("Hel"), text("lo")).droppingConnection(with: URLError(code)))

        let error = await #expect(throws: (any Error).self) { try await respond(stub) }

        #expect(outcome.matches(error), "Got \(String(describing: error))")
    }
}
