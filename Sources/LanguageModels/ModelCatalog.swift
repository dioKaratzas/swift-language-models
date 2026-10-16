/// The models a provider offers.
public protocol ModelCatalog<Details>: Sendable {
    /// The type that describes each model.
    associatedtype Details: ModelDetails

    /// Returns the models the provider offers now.
    ///
    /// - Returns: The provider's current models.
    /// - Throws: An error when the provider's model list can't be read.
    func models() async throws -> [Details]
}
