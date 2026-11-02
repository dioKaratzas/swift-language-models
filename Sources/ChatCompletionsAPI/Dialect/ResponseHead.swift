package import Foundation
package import LanguageModels

/// The headers of the response whose stream carries an answer, as a dialect's
/// ``ChatCompletionsDialect/streamState(_:)`` reads them.
///
/// Only the format's executor creates one.
package struct ResponseHead: Sendable {
    private let response: HTTPURLResponse?

    init(_ response: HTTPURLResponse?) {
        self.response = response
    }

    /// The value of one of the response's headers, or `nil` when it has none.
    package func value(for header: HTTPHeaderName) -> String? {
        response?.value(forHTTPHeaderField: header.rawValue)
    }
}
