/// Renders one `OpenRouterModel` static member per model, grouped by effort type, plus a lookup by id and a list of every
/// model.
///
/// Each member passes only the arguments that differ from the initializer's defaults.
enum OpenRouterModelsTemplate {
    static let path = "Sources/OpenRouterLanguageModels/Generated/OpenRouterModel+Catalog.swift"

    /// Where a model stands with its source.
    private enum Status {
        case current
        case retiring(on: CatalogDay)
        case removed(on: CatalogDay)

        /// The status of a model the source still lists: retiring when it has an expiration date, and current
        /// otherwise.
        init(expirationDate: CatalogDay?) {
            self = expirationDate.map(Status.retiring) ?? .current
        }

        /// The availability attribute of the model's public member, if any.
        func attribute(from source: CatalogSource) -> String? {
            switch self {
            case .current: nil
            case .retiring(let day):
                "@available(*, deprecated, message: \(SwiftLiteral.string("\(source.displayName) retires this model on \(day)")))"
            case .removed(let day): source.removedAttribute(on: day)
            }
        }

        /// Whether the model's data lives in a private member, so the lookup can reach a deprecated model without a
        /// warning.
        var hasPrivateEntry: Bool {
            if case .retiring = self { true } else { false }
        }

        /// Whether the id lookup finds the model.
        var isInLookup: Bool {
            if case .removed = self { false } else { true }
        }
    }

    private struct Member {
        let model: CatalogModel
        let name: SwiftIdentifier
        let effortType: EffortType
        let status: Status

        /// The member that holds the model's data.
        var dataName: SwiftIdentifier { status.hasPrivateEntry ? name.appending("Entry") : name }
    }

    static func render(_ snapshot: CatalogSnapshot, ranking: EffortRanking) throws(GeneratorError) -> GeneratedFile {
        let current = snapshot.models.map { model in (model, Status(expirationDate: model.expirationDate)) }
        let removed = snapshot.removed.map { ($0.model, Status.removed(on: $0.removedOn)) }
        let members = (current + removed).map { model, status in
            Member(
                model: model,
                name: SwiftIdentifier.member(for: model.id),
                effortType: EffortType(for: model, ranking: ranking),
                status: status
            )
        }
        try SwiftIdentifier.check(
            members.flatMap { member in Set([member.name, member.dataName]).map { ($0, member.model.id) } },
            reserved: SwiftIdentifier.optionalCaseNames,
            kind: "\(snapshot.source.displayName) models"
        )

        var lines = SourceText.header(from: [snapshot.source])
        lines.insert("// swift-format-ignore-file: AlwaysUseLowerCamelCase", at: 0)
        lines += ["import Foundation", "public import FoundationModels", "public import LanguageModels"]
        let groups = Dictionary(grouping: members, by: \.effortType)
        for effortType in groups.keys.sorted() {
            lines += ["", "extension OpenRouterModel where Effort == \(effortType.swiftName) {"]
            for (index, member) in groups[effortType, default: []].sorted(by: { $0.model.id < $1.model.id }).enumerated() {
                if index > 0 { lines += [""] }
                lines += try memberLines(member, source: snapshot.source)
            }
            lines += ["}"]
        }
        let listed = members.filter(\.status.isInLookup).sorted { $0.model.id < $1.model.id }
        lines += lookupLines(listed)
        lines += listLines(listed)
        return GeneratedFile(path: path, contents: SourceText.file(lines))
    }

    private static func memberLines(_ member: Member, source: CatalogSource) throws(GeneratorError) -> [String] {
        let model = member.model
        if let defaultEffort = model.defaultReasoningEffort, !member.effortType.words.contains(defaultEffort) {
            throw .invalidCatalog(
                "\(source.displayName) model \(model.id) defaults to the effort '\(defaultEffort)', which it doesn't list."
            )
        }

        var lines = SourceText.documentation(model.displayName, indent: "    ")
        if let target = model.aliasTarget {
            lines += ["    ///"] + SourceText.documentation("An alias that points to `\(target)` now.", indent: "    ")
        }
        if let attribute = member.status.attribute(from: source) { lines += ["    \(attribute)"] }
        if member.status.hasPrivateEntry {
            lines += ["    public static var \(member.name): Self { \(member.dataName) }", ""]
        }
        let access = member.status.hasPrivateEntry ? "private" : "public"
        lines += ["    \(access) static var \(member.dataName): Self {"]
        lines += initializer(of: model, efforts: member.effortType.words).lines(indent: "        ", breaks: true)
        lines += ["    }"]
        return lines
    }

    private static func initializer(of model: CatalogModel, efforts: [String]) -> SwiftExpression {
        func words(_ words: [String], unlessEqualTo defaultWords: [String]) -> SwiftExpression? {
            words == defaultWords ? nil : .array(words.map { .atom(".\(SwiftIdentifier.member(for: $0))") })
        }
        func effort(_ word: String) -> SwiftExpression { .atom(".\(SwiftIdentifier.effortCase(for: word))") }

        return .call(
            "Self",
            [
                "id": .atom(SwiftLiteral.string(model.id)),
                "displayName": .atom(SwiftLiteral.string(model.displayName)),
                "releaseDate": .atom(SwiftLiteral.date(secondsSince1970: model.releasedAt)),
                "aliasTarget": model.aliasTarget.map { .atom(SwiftLiteral.string($0)) },
                "knowledgeCutoff": model.knowledgeCutoff.map { .atom(SwiftLiteral.date($0)) },
                "expirationDate": model.expirationDate.map { .atom(SwiftLiteral.date($0)) },
                "contextSize": model.contextSize.map { .atom(SwiftLiteral.integer($0)) },
                "maximumOutputTokens": model.maximumOutputTokens.map { .atom(SwiftLiteral.integer($0)) },
                "inputModalities": words(model.inputModalities, unlessEqualTo: ["text"]),
                "outputModalities": words(model.outputModalities, unlessEqualTo: ["text"]),
                // Always written: a model built by hand has to say which parameters it takes.
                "supportedParameters": .array(model.supportedParameters.map { .atom(".\(SwiftIdentifier.member(for: $0))") }),
                "reasoning": model.reasoning == .unsupported ? nil : .atom(model.reasoning.swiftLiteral),
                "reasoningEfforts": efforts.isEmpty ? nil : .array(efforts.map(effort)),
                "defaultReasoningEffort": model.defaultReasoningEffort.map(effort),
                "cachesOnlyMarkedPrompts": model.cachesOnlyMarkedPrompts ? .atom("true") : nil,
            ]
        )
    }

    private static func lookupLines(_ members: [Member]) -> [String] {
        var lines = [
            "",
            "extension OpenRouterModel where Effort == ContextOptions.ReasoningLevel {",
            "    /// The catalog's model with the given id, with its efforts in their open form, or `nil` when the catalog",
            "    /// doesn't list the id.",
            "    ///",
            "    /// - Parameter id: An OpenRouter model id, such as `typesafe/jev-router`.",
            "    public init?(catalogID id: OpenRouterModelID) {",
            "        switch id.rawValue {",
        ]
        for member in members {
            lines += [
                "        case \(SwiftLiteral.string(member.model.id)):",
                "            self.init(OpenRouterModel<\(member.effortType.swiftName)>.\(member.dataName))",
            ]
        }
        lines += ["        default:", "            return nil", "        }", "    }", "}"]
        return lines
    }

    /// The list of every model the lookup finds, in the same order. A retiring model is read through its data member,
    /// so the list builds without a deprecation warning.
    private static func listLines(_ members: [Member]) -> [String] {
        var lines = [
            "",
            "extension OpenRouterModel where Effort == ContextOptions.ReasoningLevel {",
            "    /// Every model in the catalog, sorted by id, with their efforts in their open form, such as for listing the",
            "    /// models a person can pick from. Models OpenRouter removed aren't listed.",
            "    ///",
            "    /// The list is built on each read, so read it once rather than in a loop.",
            "    public static var catalogModels: [Self] {",
            "        [",
        ]
        for member in members {
            lines += ["            Self(OpenRouterModel<\(member.effortType.swiftName)>.\(member.dataName)),"]
        }
        lines += ["        ]", "    }", "}"]
        return lines
    }
}
