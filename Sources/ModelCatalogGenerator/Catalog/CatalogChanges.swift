import Foundation

/// How one source's catalog changed since an earlier version, and the release the generated code needs for it.
///
/// The release follows semantic versioning of the generated code:
/// - major: code that compiled may stop compiling, because a model's static is deleted, a model loses effort levels, or
///   a word, effort or effort set is deleted;
/// - minor: members are added, deprecated or marked unavailable, because a model or word is added, retiring, gone from
///   the source or back again, or a model gains effort levels. A member marked unavailable breaks code that names it, but
///   the source no longer serves it either;
/// - patch: anything else in the snapshot, such as a model's limits, name, dates or parameters;
/// - none: the snapshots are equal. A change to the source's API shape alone releases nothing, since no code changes.
struct CatalogChanges: Codable, Equatable, Sendable {
    /// The release a change needs.
    enum Bump: String, Codable, CaseIterable, Comparable, Sendable {
        case none
        case patch
        case minor
        case major

        static func < (lhs: Self, rhs: Self) -> Bool {
            allCases.firstIndex(of: lhs) ?? 0 < allCases.firstIndex(of: rhs) ?? 0
        }
    }

    /// A change to the generated members, such as an added or deprecated model, worded for a changelog.
    struct MemberChange: Codable, Equatable, Sendable {
        let bump: Bump
        let summary: String
    }

    /// A change to a listed model's data, with each changed field's old and new value.
    struct ModelChange: Codable, Equatable, Sendable {
        let id: String
        /// One entry per field, such as `maximumOutputTokens 65,536 → 163,840`.
        let fields: [String]
    }

    let source: CatalogSource
    let members: [MemberChange]
    let models: [ModelChange]
    /// How the source's API changed shape, which the decoder would otherwise ignore.
    let api: [String]
    /// The release the changes need.
    let bump: Bump
}

extension CatalogChanges {
    /// The changes between two versions of a source's snapshot and schema.
    ///
    /// - Parameters:
    ///   - old: The earlier snapshot, or `nil` when the source is new.
    ///   - new: The current snapshot.
    ///   - oldSchema: The earlier schema, or `nil` when there was none.
    ///   - newSchema: The current schema, or `nil` when there is none.
    init(from old: CatalogSnapshot?, to new: CatalogSnapshot, oldSchema: CatalogSchema?, newSchema: CatalogSchema?) {
        var members = Self.statics(from: old, to: new, source: new.source)
        members += Self.efforts(from: old?.models ?? [], to: new.models)
        members += Self.entries(from: old.map(Self.entries(of:)) ?? [], to: Self.entries(of: new), source: new.source)
        let models = Self.models(from: old?.models ?? [], to: new.models)
        if old != new, members.isEmpty, models.isEmpty {
            members.append(MemberChange(bump: .patch, summary: "Changes other catalog data, such as the order of the efforts."))
        }
        self.init(
            source: new.source,
            members: members,
            models: models,
            api: oldSchema.flatMap { oldSchema in newSchema?.changes(since: oldSchema) } ?? [],
            bump: max(members.map(\.bump).max() ?? .none, models.isEmpty ? .none : .patch)
        )
    }

    /// The models added, retiring, gone from the source, listed again or deleted. Each model has a static, whether it's
    /// listed or removed.
    private static func statics(from old: CatalogSnapshot?, to new: CatalogSnapshot, source: CatalogSource) -> [MemberChange] {
        let oldListed = Dictionary(uniqueKeysWithValues: (old?.models ?? []).map { ($0.id, $0) })
        let oldRemoved = Set((old?.removed ?? []).map(\.model.id))
        let newRemoved = Dictionary(uniqueKeysWithValues: new.removed.map { ($0.model.id, $0.removedOn) })
        let oldStatics = Set(oldListed.keys).union(oldRemoved)
        let newStatics = Set(new.models.map(\.id)).union(newRemoved.keys)

        var changes: [MemberChange] = oldStatics.subtracting(newStatics).sorted().map {
            MemberChange(bump: .major, summary: "Deletes `\($0)`.")
        }
        for model in new.models {
            if !oldStatics.contains(model.id) {
                let expiry = model.expirationDate.map { ", which \(source.displayName) retires on \($0)" } ?? ""
                changes.append(MemberChange(bump: .minor, summary: "Adds `\(model.id)`\(expiry)."))
            } else if oldRemoved.contains(model.id) {
                changes.append(MemberChange(bump: .minor, summary: "Brings back `\(model.id)`: \(source.displayName) lists it again."))
            } else if let expirationDate = model.expirationDate, oldListed[model.id]?.expirationDate == nil {
                let summary = "Deprecates `\(model.id)`: \(source.displayName) retires it on \(expirationDate)."
                changes.append(MemberChange(bump: .minor, summary: summary))
            }
        }
        for (id, removedOn) in newRemoved.sorted(by: { $0.key < $1.key }) where oldListed[id] != nil {
            let summary = "Marks `\(id)` unavailable: \(source.displayName) stopped listing it on \(removedOn)."
            changes.append(MemberChange(bump: .minor, summary: summary))
        }
        return changes
    }

    /// The effort levels each model that's listed in both versions gains or loses.
    private static func efforts(from old: [CatalogModel], to new: [CatalogModel]) -> [MemberChange] {
        let oldModels = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        return new.flatMap { model -> [MemberChange] in
            guard let oldModel = oldModels[model.id] else { return [] }
            let lost = oldModel.reasoningEfforts.filter { !model.reasoningEfforts.contains($0) }
            let gained = model.reasoningEfforts.filter { !oldModel.reasoningEfforts.contains($0) }
            return (lost.isEmpty ? [] : [MemberChange(bump: .major, summary: "`\(model.id)` loses the effort levels \(code(lost)).")])
                + (gained.isEmpty ? [] : [MemberChange(bump: .minor, summary: "`\(model.id)` gains the effort levels \(code(gained)).")])
        }
    }

    /// A vocabulary word, effort or effort set, named for a changelog.
    private struct Entry {
        let name: String
        let summary: String?
        let isRemoved: Bool
    }

    /// Every vocabulary word, effort and effort set of a snapshot.
    private static func entries(of snapshot: CatalogSnapshot) -> [Entry] {
        let words = snapshot.vocabularies.sorted { $0.key.rawValue < $1.key.rawValue }.flatMap { vocabulary, words in
            words.map { Entry(name: "`\(vocabulary.rawValue)` word `\($0.word)`", summary: $0.summary, isRemoved: $0.removedOn != nil) }
        }
        let efforts = snapshot.efforts.map { Entry(name: "effort `\($0.word)`", summary: $0.summary, isRemoved: $0.removedOn != nil) }
        let sets = snapshot.effortSets.map {
            Entry(name: "effort set `\($0.words.joined(separator: " "))`", summary: nil, isRemoved: $0.removedOn != nil)
        }
        return words + efforts + sets
    }

    /// The vocabulary words, efforts and effort sets added, marked unavailable, used again, deleted or described anew.
    private static func entries(from old: [Entry], to new: [Entry], source: CatalogSource) -> [MemberChange] {
        let oldEntries = Dictionary(old.map { ($0.name, $0) }) { first, _ in first }
        let newNames = Set(new.map(\.name))
        var changes = old.filter { !newNames.contains($0.name) }.map { MemberChange(bump: .major, summary: "Deletes the \($0.name).") }
        for entry in new {
            guard let oldEntry = oldEntries[entry.name] else {
                if !entry.isRemoved { changes.append(MemberChange(bump: .minor, summary: "Adds the \(entry.name).")) }
                continue
            }
            if entry.isRemoved, !oldEntry.isRemoved {
                changes.append(
                    MemberChange(bump: .minor, summary: "Marks the \(entry.name) unavailable: \(source.displayName) dropped it."))
            } else if !entry.isRemoved, oldEntry.isRemoved {
                changes.append(MemberChange(bump: .minor, summary: "Brings back the \(entry.name)."))
            } else if entry.summary != oldEntry.summary {
                changes.append(MemberChange(bump: .patch, summary: "Rewords the summary of the \(entry.name)."))
            }
        }
        return changes
    }

    /// The data changes of each model that's listed in both versions.
    private static func models(from old: [CatalogModel], to new: [CatalogModel]) -> [ModelChange] {
        let oldModels = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        return new.compactMap { model in
            guard let oldModel = oldModels[model.id], oldModel != model else { return nil }
            let fields = fieldChanges(from: oldModel, to: model)
            return ModelChange(id: model.id, fields: fields.isEmpty ? ["changes data"] : fields)
        }
    }

    /// Each field that differs, with its old and new value, or the words a list adds and drops.
    private static func fieldChanges(from old: CatalogModel, to new: CatalogModel) -> [String] {
        var changes: [String] = []
        func compare<Value: Equatable>(_ name: String, _ keyPath: KeyPath<CatalogModel, Value>, _ describe: (Value) -> String) {
            let (before, after) = (old[keyPath: keyPath], new[keyPath: keyPath])
            if before != after { changes.append("\(name) \(describe(before)) → \(describe(after))") }
        }
        func compareWords(_ name: String, _ keyPath: KeyPath<CatalogModel, [String]>) {
            let (before, after) = (Set(old[keyPath: keyPath]), Set(new[keyPath: keyPath]))
            let added = after.subtracting(before).sorted()
            let dropped = before.subtracting(after).sorted()
            let parts = (added.isEmpty ? [] : ["adds \(code(added))"]) + (dropped.isEmpty ? [] : ["drops \(code(dropped))"])
            if !parts.isEmpty { changes.append("\(name) \(parts.joined(separator: ", "))") }
        }
        func optional<Value>(_ describe: @escaping (Value) -> String) -> (Value?) -> String {
            { $0.map(describe) ?? "none" }
        }
        let day = { (day: CatalogDay) in day.description }
        let number = { (value: Int) in value.formatted(.number.locale(Locale(identifier: "en_US"))) }

        compare("displayName", \.displayName) { "\"\($0)\"" }
        compare("aliasTarget", \.aliasTarget, optional { "`\($0)`" })
        compare("releasedAt", \.releasedAt) { Date(timeIntervalSince1970: TimeInterval($0)).formatted(.iso8601) }
        compare("knowledgeCutoff", \.knowledgeCutoff, optional(day))
        compare("expirationDate", \.expirationDate, optional(day))
        compare("contextSize", \.contextSize, optional(number))
        compare("maximumOutputTokens", \.maximumOutputTokens, optional(number))
        compareWords("inputModalities", \.inputModalities)
        compareWords("outputModalities", \.outputModalities)
        compareWords("supportedParameters", \.supportedParameters)
        compare("reasoningEfforts", \.reasoningEfforts) { $0.isEmpty ? "none" : code($0) }
        compare("defaultReasoningEffort", \.defaultReasoningEffort, optional { "`\($0)`" })
        compare("reasoning", \.reasoning) { "`\($0.word)`" }
        compare("cachesOnlyMarkedPrompts", \.cachesOnlyMarkedPrompts) { "\($0)" }
        return changes
    }

    /// Words as code, separated by commas.
    private static func code(_ words: [String]) -> String {
        words.map { "`\($0)`" }.joined(separator: ", ")
    }
}

extension [CatalogChanges] {
    /// The release that all the sources' changes need together.
    var bump: CatalogChanges.Bump {
        map(\.bump).max() ?? .none
    }

    /// The changes as Markdown, for a pull request and its release notes.
    var changelog: String {
        var lines = ["**Release:** `\(bump.rawValue)`"]
        if bump == .none { lines[0] += ", since the generated code doesn't change." }
        func section(_ title: String, _ items: [String]) {
            guard !items.isEmpty else { return }
            lines += ["", "### \(title)", ""] + items.map { "- \($0)" }
        }
        for changes in self {
            let name = changes.source.displayName
            section("\(name) models and words", changes.members.map(\.summary))
            section("\(name) model data", changes.models.map { "`\($0.id)`: \($0.fields.joined(separator: "; "))." })
            section("\(name) API shape", changes.api)
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
