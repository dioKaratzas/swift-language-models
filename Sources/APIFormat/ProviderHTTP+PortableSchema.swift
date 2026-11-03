package import Foundation
package import LanguageModels

extension ProviderHTTP {
    /// Opens a format's response stream, and opens it once more with the portable schema when the host rejects a
    /// constraint of the full one.
    ///
    /// - Parameters:
    ///   - request: The request, whose body becomes the portable one for the second try.
    ///   - portableSchemaBody: The body with its response schema in portable form, or `nil` when there's none to try.
    ///   - log: The request's log.
    /// - Returns: The stream, and the headers of its response.
    /// - Throws: ``ProviderHTTP/Failure`` for a response whose status isn't a success, after the retries, which the
    ///   format turns into the dialect's error, and a failed connection's error.
    package func openStream(
        _ request: inout URLRequest,
        portableSchemaBody: JSONValue?,
        log: OperationLog
    ) async throws -> (URLSession.AsyncBytes, ResponseHeaders) {
        var portableSchemaBody = portableSchemaBody
        while true {
            let rejected: ProviderHTTP.Failure
            do {
                return try await stream(request) { log.retrying(status: $0, after: $1) }
            } catch let failure as ProviderHTTP.Failure {
                rejected = failure
            }
            guard let body = portableSchemaBody,
                SchemaConstraint.isRejected(status: rejected.status, message: String(decoding: rejected.body, as: UTF8.self))
            else { throw rejected }
            log.retryingWithPortableSchema(host: nil)
            request.httpBody = body.data
            portableSchemaBody = nil
        }
    }
}
