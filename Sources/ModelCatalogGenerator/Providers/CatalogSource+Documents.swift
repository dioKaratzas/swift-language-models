import Foundation

extension CatalogSource {
    /// The documents a fetch reads from a source.
    struct Documents: Sendable {
        /// A document a fetch reads.
        enum Kind: Sendable, CustomStringConvertible {
            /// The list of the source's models.
            case modelList
            /// The source's OpenAPI description, which lists the whole vocabularies and describes their words.
            case apiDescription
            /// The list of the models the provider still serves, for a source whose model list describes models the
            /// provider no longer serves too.
            case servedModels

            var description: String {
                switch self {
                case .modelList: "a model list"
                case .apiDescription: "an API description"
                case .servedModels: "a list of served models"
                }
            }
        }

        let modelList: Data
        let apiDescription: Data
        /// The served models, for a source that has a list of them.
        var servedModels: Data?
    }
}
