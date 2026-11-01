import Foundation
import FoundationModels
import os

/// What a request executor reports of an answer it streamed, which the model's executor checks.
///
/// ``DetailedLanguageModelRequestExecutor/execute(_:model:streamingInto:)`` returns it once the answer's events are
/// sent. For a request with a schema, ``DetailedLanguageModelExecutor`` checks the response's text against the
/// schema's guides, since a host may drop or ignore constraints such as a guide's minimum.
public struct DetailedLanguageModelAnswer: Sendable {
    /// The text of the answer's response entry, as the request executor sent it, or empty when the answer ended in
    /// tool calls.
    public var responseText: String

    /// Creates the report of an answer.
    ///
    /// - Parameter responseText: The text of the answer's response entry, as the request executor sent it, or empty
    ///   when the answer ended in tool calls.
    public init(responseText: String) {
        self.responseText = responseText
    }
}

extension DetailedLanguageModelAnswer {
    /// Checks the response's text against the guides of the request's schema.
    ///
    /// A response that isn't JSON, or a schema that can't be encoded, passes, for decoding to report.
    ///
    /// - Parameters:
    ///   - schema: The request's schema.
    ///   - request: The start of the request's id, which names the request in the log.
    /// - Throws: `GeneratedContent.ParsingError`, naming each value that breaks a guide, when one does.
    func checkGuides(of schema: GenerationSchema, request: String) throws {
        guard !responseText.isEmpty, let answer = try? JSONValue(json: Data(responseText.utf8)),
            let json = try? JSONValue(schema, strict: true)
        else { return }
        let violations = answer.violations(of: json)
        guard !violations.isEmpty else { return }
        // The log names where each value is and the guide it breaks, never the value, which is part of the answer.
        let places = violations.map { "\($0.path.isEmpty ? "the answer" : $0.path) (\($0.keyword))" }.joined(separator: ", ")
        PackageLogger.languageModels(.error)?.error(
            "Request \(request, privacy: .public): the answer breaks its schema's guides at \(places, privacy: .public).")
        throw GeneratedContent.ParsingError(
            rawContent: responseText,
            debugDescription: "The answer breaks its schema's guides: \(violations.map(\.description).joined(separator: "; ")).")
    }
}
