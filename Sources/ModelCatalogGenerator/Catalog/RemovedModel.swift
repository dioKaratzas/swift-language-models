/// A model that disappeared from its source, kept so its generated member stays, marked unavailable.
struct RemovedModel: Codable, Equatable, Sendable {
    let model: CatalogModel
    /// The day the model disappeared.
    let removedOn: CatalogDay
}
