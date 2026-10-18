extension Unicode.Scalar {
    /// Whether the scalar shows as itself in source text: not a control, format or separator character, and not
    /// unassigned or private.
    ///
    /// Format characters include the ones that reorder text, so source can't display differently from what it does.
    var isPrintable: Bool {
        switch properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator, .surrogate, .privateUse, .unassigned: false
        default: true
        }
    }
}
