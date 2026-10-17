import Foundation

/// Renders one `OpenRouterModel` static member per model, grouped by effort type, plus a lookup by id.
enum OpenRouterModelsTemplate {
    static let path = "Sources/OpenRouterLanguageModels/Generated/OpenRouterModel+Catalog.swift"

    private struct Member {
        let model: CatalogModel
        let name: String
        let effortType: EffortType
        let isRemoved: Bool
        let deprecation: String?

        /// The member that holds the model's data. A model that OpenRouter still offers but has deprecated keeps its
        /// data in a private member, so the lookup can use it without a deprecation warning.
        var dataName: String { deprecation != nil && !isRemoved ? "\(name)Entry" : name }
    }

    static func render(_ snapshot: CatalogSnapshot, ranking: [String]) throws(GeneratorError) -> GeneratedFile {
        let current = snapshot.models.map { ($0, false) }
        let removed = snapshot.removed.map { ($0.model, true) }
        let members = (current + removed).map { model, isRemoved in
            Member(
                model: model,
                name: SwiftIdentifier.member(for: model.id),
                effortType: EffortType(for: model, ranking: ranking),
                isRemoved: isRemoved,
                deprecation: isRemoved
                    ? "Removed from \(snapshot.source.displayName)"
                    : model.expirationDate.map { "\(snapshot.source.displayName) retires this model on \($0)" }
            )
        }
        let namedMembers = members.flatMap { member in Set([member.name, member.dataName]).map { ($0, member.model.id) } }
        let collisions = Dictionary(grouping: namedMembers, by: \.0).filter { $0.value.count > 1 }
        guard collisions.isEmpty else {
            let ids = collisions.values.flatMap { $0.map(\.1) }.sorted()
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
                lines += try memberLines(member, source: snapshot.source)
            }
            lines += ["}"]
        }
        lines += lookupLines(members.filter { !$0.isRemoved }.sorted { $0.model.id < $1.model.id })
        return GeneratedFile(path: path, contents: SourceText.file(lines))
    }

    private static let indent = "            "

    private static func memberLines(_ member: Member, source: CatalogSource) throws(GeneratorError) -> [String] {
        let model = member.model
        var lines = ["    /// \(model.displayName.trimmingCharacters(in: .whitespaces))"]
        if let deprecation = member.deprecation {
            lines += ["    @available(*, deprecated, message: \(SwiftLiteral.string(deprecation)))"]
        }
        if member.dataName != member.name {
            lines += ["    public static var \(member.name): Self { \(member.dataName) }", ""]
        }
        func value(_ label: String, _ value: String?) -> String { "\(indent)\(label): \(value ?? "nil")," }
        func argument(_ label: String, _ elements: [String]) -> [String] {
            SourceText.array("\(label): ", elements, indent: indent, suffix: ",")
        }
        func day(_ text: String?, _ field: String) throws(GeneratorError) -> String? {
            try literal(text, field, of: model, from: source, SwiftLiteral.date(day:))
        }
        func effort(_ word: String) -> String { ".\(SwiftIdentifier.effortCase(for: word))" }
        let efforts = if case .set(let words) = member.effortType { words } else { [String]() }
        let reasoning =
            model.isReasoningMandatory
            ? ".mandatory" : model.reasons ? ".optional(enabledByDefault: \(model.reasonsByDefault))" : ".unsupported"

        let access = member.dataName == member.name ? "public" : "private"
        lines += [
            "    \(access) static var \(member.dataName): Self {",
            "        Self(",
            value("id", SwiftLiteral.string(model.id)),
            value("displayName", SwiftLiteral.string(model.displayName)),
            value("releaseDate", SwiftLiteral.date(secondsSince1970: model.releasedAt)),
            value("knowledgeCutoff", try day(model.knowledgeCutoff, "knowledge cutoff")),
            value("expirationDate", try day(model.expirationDate, "expiration date")),
            value("contextSize", model.contextSize.map(SwiftLiteral.integer)),
            value("maximumResponseTokens", model.maximumResponseTokens.map(SwiftLiteral.integer)),
        ]
        lines += argument("inputModalities", model.inputModalities.map(SwiftLiteral.string))
        lines += argument("outputModalities", model.outputModalities.map(SwiftLiteral.string))
        lines += argument("supportedParameters", model.supportedParameters.map(SwiftLiteral.string))
        lines += [value("reasoning", reasoning)]
        lines += argument("reasoningEfforts", efforts.map(effort))
        lines += [value("defaultReasoningEffort", model.defaultReasoningEffort.map(effort))]
        lines += try pricingLines(of: model, from: source)
        lines += ["        )", "    }"]
        return lines
    }

    private static func pricingLines(of model: CatalogModel, from source: CatalogSource) throws(GeneratorError) -> [String] {
        guard let pricing = model.pricing else { return ["\(indent)pricing: nil"] }
        func price(_ text: String?, _ field: String) throws(GeneratorError) -> String {
            try literal(text, field, of: model, from: source, SwiftLiteral.decimal) ?? "nil"
        }
        return [
            "\(indent)pricing: OpenRouterPricing(",
            "\(indent)    prompt: \(try price(pricing.prompt, "prompt price")),",
            "\(indent)    completion: \(try price(pricing.completion, "completion price")),",
            "\(indent)    cacheRead: \(try price(pricing.cacheRead, "cache read price")),",
            "\(indent)    cacheWrite: \(try price(pricing.cacheWrite, "cache write price"))",
            "\(indent))",
        ]
    }

    /// The Swift literal for a catalog value, or `nil` when the catalog has none.
    ///
    /// - Throws: ``GeneratorError/invalidCatalog(_:)`` when the value can't become a literal, so a broken value
    ///   fails the render instead of vanishing from the code.
    private static func literal(
        _ text: String?,
        _ field: String,
        of model: CatalogModel,
        from source: CatalogSource,
        _ make: (String) -> String?
    ) throws(GeneratorError) -> String? {
        guard let text else { return nil }
        guard let literal = make(text) else {
            throw .invalidCatalog("\(source.displayName) model \(model.id) has an invalid \(field): '\(text)'.")
        }
        return literal
    }

    private static func lookupLines(_ members: [Member]) -> [String] {
        var lines = [
            "",
            "extension OpenRouterModel where Effort == ContextOptions.ReasoningLevel {",
            "    /// The catalog's model with the given id, with its efforts in their open form.",
            "    ///",
            "    /// - Parameter id: An OpenRouter model id, such as `typesafe/jev-router`.",
            "    /// - Returns: The model, or `nil` when the catalog doesn't list the id.",
            "    public init?(catalogID id: OpenRouterModelID) {",
            "        switch id {",
        ]
        for member in members {
            lines += ["        case \(SwiftLiteral.string(member.model.id)):"]
            lines += [
                member.effortType == .open
                    ? "            self = .\(member.dataName)"
                    : "            self.init(OpenRouterModel<\(member.effortType.swiftName)>.\(member.dataName))"
            ]
        }
        lines += ["        default:", "            return nil", "        }", "    }", "}"]
        return lines
    }
}
