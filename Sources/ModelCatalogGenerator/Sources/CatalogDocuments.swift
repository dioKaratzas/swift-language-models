import Foundation

/// The documents a fetch reads from a source.
struct CatalogDocuments: Sendable {
    /// A document a fetch reads.
    enum Kind: Sendable, CustomStringConvertible {
        /// The list of the source's models.
        case modelList
        /// The source's OpenAPI description, which lists the whole vocabularies and describes their words.
        case apiDescription

        var description: String {
            switch self {
            case .modelList: "a model list"
            case .apiDescription: "an API description"
            }
        }
    }

    let modelList: Data
    let apiDescription: Data
}
