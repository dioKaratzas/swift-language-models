extension CatalogSnapshot {
    /// Each model, listed or removed, with its member name, sorted by id. The model's type name is the same name,
    /// capitalized.
    ///
    /// Models whose ids give the same name take turns by release, earliest first, then by id, whether they're listed
    /// or removed. The first keeps the name, and each next one gets the lowest numbered suffix from `_2` that no model
    /// before it took, such as `xM1_5_2`. The names depend only on the snapshot, and removing a model doesn't change
    /// its release, so a removal renames nothing, and neither does a new model, which the source lists last.
    var namedModels: [(model: CatalogModel, name: SwiftIdentifier)] {
        let inTurn = (models + removed.map(\.model)).sorted { lhs, rhs in
            lhs.releasedAt != rhs.releasedAt ? lhs.releasedAt < rhs.releasedAt : lhs.id < rhs.id
        }
        var taken: Set<SwiftIdentifier> = []
        let named = inTurn.map { model in
            let base = SwiftIdentifier.member(for: model.id)
            var name = base
            // An empty name stays empty, so the check reports it.
            var number = 2
            while !base.name.isEmpty, taken.contains(name) {
                name = base.appending("_\(number)")
                number += 1
            }
            taken.insert(name)
            return (model: model, name: name)
        }
        return named.sorted { $0.model.id < $1.model.id }
    }
}
