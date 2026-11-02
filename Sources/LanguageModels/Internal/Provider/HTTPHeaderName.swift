/// The name of an HTTP header, such as `Authorization`.
///
/// Header names are compared as written, so a provider spells each the same way everywhere, as the names here do.
package struct HTTPHeaderName: ProviderVocabulary {
    /// The media types a response may have.
    package static let accept: Self = "Accept"

    /// The credentials of a request, such as `Bearer …`.
    package static let authorization: Self = "Authorization"

    /// The media type of a request's body.
    package static let contentType: Self = "Content-Type"

    /// How long a response asks to wait before trying again.
    package static let retryAfter: Self = "Retry-After"

    /// The client that sends a request.
    package static let userAgent: Self = "User-Agent"

    package let rawValue: String

    package init(rawValue: String) {
        self.rawValue = rawValue
    }
}
