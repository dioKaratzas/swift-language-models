extension CatalogReasoning {
    /// The matching `ModelReasoning` member in generated code.
    var swiftLiteral: String {
        switch self {
        case .unsupported: ".unsupported"
        case .optional(enabledByDefault: false): ".offByDefault"
        case .optional(enabledByDefault: true): ".onByDefault"
        case .mandatory: ".mandatory"
        }
    }
}
