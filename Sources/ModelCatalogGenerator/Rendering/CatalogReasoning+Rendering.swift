extension CatalogReasoning {
    /// The matching `OpenRouterReasoning` value in generated code.
    var swiftLiteral: String {
        switch self {
        case .unsupported: ".unsupported"
        case .optional(let enabledByDefault): ".optional(enabledByDefault: \(enabledByDefault))"
        case .mandatory: ".mandatory"
        }
    }
}
