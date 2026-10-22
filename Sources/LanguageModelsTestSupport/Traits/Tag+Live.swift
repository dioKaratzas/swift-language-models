package import Testing

extension Tag {
    /// Tests that call a provider's live API.
    @Tag package static var live: Self

    /// Tests that sweep many of a provider's models through its live API, which run only when asked for.
    @Tag package static var liveSweep: Self
}
