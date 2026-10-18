extension Sequence where Element: Hashable {
    /// The elements without repeats, each where it first appears.
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
