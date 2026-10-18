/// Whether and when a catalog model reasons, as one value, so no impossible combination of flags can reach the code.
enum CatalogReasoning: Equatable {
    case unsupported
    case optional(enabledByDefault: Bool)
    case mandatory
}
