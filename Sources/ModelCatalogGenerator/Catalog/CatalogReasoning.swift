/// Whether and when a catalog model reasons, as one value, so no impossible combination of flags can reach the code.
enum CatalogReasoning: Equatable {
    case unsupported
    case optional(enabledByDefault: Bool)
    case mandatory

    /// The matching `OpenRouterReasoning` value in generated code.
    var swiftLiteral: String {
        switch self {
        case .unsupported: ".unsupported"
        case .optional(let enabledByDefault): ".optional(enabledByDefault: \(enabledByDefault))"
        case .mandatory: ".mandatory"
        }
    }
}
