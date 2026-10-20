package import Foundation

/// JSON text with sorted keys and fixed formatting, so two documents compare equal when their values match.
///
/// - Parameter data: A JSON document.
/// - Returns: The document in canonical form.
/// - Throws: An error when `data` isn't valid JSON.
package func canonicalJSON(_ data: Data) throws -> String {
    let object = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    let canonical = try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes, .fragmentsAllowed]
    )
    return String(decoding: canonical, as: UTF8.self)
}

/// JSON text with sorted keys and fixed formatting, so two documents compare equal when their values match.
///
/// - Parameter text: A JSON document.
/// - Returns: The document in canonical form.
/// - Throws: An error when `text` isn't valid JSON.
package func canonicalJSON(_ text: String) throws -> String {
    try canonicalJSON(Data(text.utf8))
}
