import Foundation

/// Renders one `OpenRouterModel` static member per model, grouped by effort type, plus a lookup by id.
enum OpenRouterModelsTemplate {
    static let path = "Sources/OpenRouterLanguageModels/Generated/OpenRouterModel+Catalog.swift"

    private struct Member {
        let model: CatalogModel
        let name: String
        let effortType: EffortType
        let isRemoved: Bool
    }

    static func render(_ snapshot: CatalogSnapshot, ranking: [String]) throws(GeneratorError) -> GeneratedFile {
        let current = snapshot.models.map { ($0, false) }
        let removed = snapshot.removed.map { ($0.model, true) }
        let members = (current + removed).map { model, isRemoved in
            Member(
                model: model,
                name: SwiftIdentifier.member(for: model.id),
                effortType: EffortType(for: model, ranking: ranking),
                isRemoved: isRemoved
            )
        }
        let collisions = Dictionary(grouping: members, by: \.name).filter { $0.value.count > 1 }
        guard collisions.isEmpty else {
            let ids = collisions.values.flatMap { $0.map(\.model.id) }.sorted()
            throw .invalidCatalog("These OpenRouter models get the same Swift name: \(ids.joined(separator: ", ")).")
        }

        var lines = SourceText.header(from: [snapshot.source])
        lines.insert("// swift-format-ignore-file: AlwaysUseLowerCamelCase", at: 0)
        lines += ["import Foundation", "public import FoundationModels", "public import LanguageModels"]
        let groups = Dictionary(grouping: members, by: \.effortType)
        for effortType in groups.keys.sorted() {
            lines += ["", "extension OpenRouterModel where Effort == \(effortType.swiftName) {"]
            for (index, member) in groups[effortType, default: []].sorted(by: { $0.model.id < $1.model.id }).enumerated() {
                if index > 0 { lines += [""] }
                lines += memberLines(member, source: snapshot.source)
            }
            lines += ["}"]
        }
        lines += lookupLines(members.filter { !$0.isRemoved }.sorted { $0.model.id < $1.model.id })
        return GeneratedFile(path: path, contents: SourceText.file(lines))
    }

    private static func memberLines(_ member: Member, source: CatalogSource) -> [String] {
        let model = member.model
        let indent = "            "
        var lines = ["    /// \(model.displayName.trimmingCharacters(in: .whitespaces))"]
        if member.isRemoved {
            lines += ["    @available(*, deprecated, message: \(SwiftLiteral.string("Removed from \(source.displayName)")))"]
        }
        func value(_ label: String, _ value: String?) -> String { "\(indent)\(label): \(value ?? "nil")," }
        func argument(_ label: String, _ elements: [String]) -> [String] {
            SourceText.array("\(label): ", elements, indent: indent, suffix: ",")
        }
        func effort(_ word: String) -> String { ".\(SwiftIdentifier.effortCase(for: word))" }
        let efforts = if case .set(let words) = member.effortType { words } else { [String]() }

        lines += [
            "    public static var \(member.name): Self {",
            "        Self(",
            value("id", SwiftLiteral.string(model.id)),
            value("displayName", SwiftLiteral.string(model.displayName)),
            value("releaseDate", SwiftLiteral.date(secondsSince1970: model.releasedAt)),
            value("knowledgeCutoff", model.knowledgeCutoff.flatMap(SwiftLiteral.date(day:))),
            value("expirationDate", model.expirationDate.flatMap(SwiftLiteral.date(day:))),
            value("contextSize", model.contextSize.map(SwiftLiteral.integer)),
            value("maximumResponseTokens", model.maximumResponseTokens.map(SwiftLiteral.integer)),
        ]
        lines += argument("inputModalities", model.inputModalities.map(SwiftLiteral.string))
        lines += argument("outputModalities", model.outputModalities.map(SwiftLiteral.string))
        lines += argument("supportedParameters", model.supportedParameters.map(SwiftLiteral.string))
        lines += argument("reasoningEfforts", efforts.map(effort))
        lines += [
            value("defaultReasoningEffort", model.defaultReasoningEffort.map(effort)),
            value("isReasoningMandatory", "\(model.isReasoningMandatory)"),
            value("reasonsByDefault", "\(model.reasonsByDefault)"),
        ]
        lines += pricingLines(model.pricing, indent: indent)
        lines += ["        )", "    }"]
        return lines
    }

    private static func pricingLines(_ pricing: CatalogModel.Pricing?, indent: String) -> [String] {
        guard let pricing, let prompt = SwiftLiteral.decimal(pricing.prompt),
            let completion = SwiftLiteral.decimal(pricing.completion)
        else { return ["\(indent)pricing: nil"] }
        return [
            "\(indent)pricing: OpenRouterPricing(",
            "\(indent)    prompt: \(prompt),",
            "\(indent)    completion: \(completion),",
            "\(indent)    cacheRead: \(pricing.cacheRead.flatMap(SwiftLiteral.decimal) ?? "nil"),",
            "\(indent)    cacheWrite: \(pricing.cacheWrite.flatMap(SwiftLiteral.decimal) ?? "nil")",
            "\(indent))",
        ]
    }

    private static func lookupLines(_ members: [Member]) -> [String] {
        var lines = [
            "",
            "extension OpenRouterModel where Effort == ContextOptions.ReasoningLevel {",
            "    /// The catalog's model with the given id, with its efforts in their open form.",
            "    ///",
            "    /// - Parameter id: An OpenRouter model id, such as `typesafe/jev-router`.",
            "    /// - Returns: The model, or `nil` when the catalog doesn't list the id.",
            "    public init?(catalogID id: String) {",
            "        switch id {",
        ]
        for member in members {
            lines += ["        case \(SwiftLiteral.string(member.model.id)):"]
            lines += [
                member.effortType == .open
                    ? "            self = .\(member.name)"
                    : "            self.init(OpenRouterModel<\(member.effortType.swiftName)>.\(member.name))"
            ]
        }
        lines += ["        default:", "            return nil", "        }", "    }", "}"]
        return lines
    }
}
