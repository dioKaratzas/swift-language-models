/// Renders one `OpenRouterModel` static member per model, grouped by effort type, plus a lookup by id.
///
/// Each member passes only the arguments that differ from the initializer's defaults.
enum OpenRouterModelsTemplate {
    static let path = "Sources/OpenRouterLanguageModels/Generated/OpenRouterModel+Catalog.swift"

    /// Where a model stands with its source.
    private enum Status {
        case current
        case retiring(on: String)
        case removed

        /// The availability attribute of the model's public member, if any.
        func attribute(from source: CatalogSource) -> String? {
            switch self {
            case .current: nil
            case .retiring(let day):
                "@available(*, deprecated, message: \(SwiftLiteral.string("\(source.displayName) retires this model on \(day)")))"
            case .removed: source.removedAttribute
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

    /// Lowercase English day names, the way OpenRouter spells the days of a price override.
    private static let weekdays: Set<String> = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    /// The end of a window that runs to midnight, as an `HHMM` clock number.
    private static let midnightAtEnd = 2_400

    static func render(_ snapshot: CatalogSnapshot, ranking: EffortRanking) throws(GeneratorError) -> GeneratedFile {
        let current = snapshot.models.map { model in (model, model.expirationDate.map(Status.retiring) ?? .current) }
        let removed = snapshot.removed.map { ($0.model, Status.removed) }
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
        lines += lookupLines(members.filter(\.status.isInLookup).sorted { $0.model.id < $1.model.id })
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
        lines += try initializer(of: model, efforts: member.effortType.words, from: source).lines(indent: "        ", breaks: true)
        lines += ["    }"]
        return lines
    }

    /// Turns one model's catalog values into literals, and names the model when a value can't become one.
    private struct Literals {
        let model: CatalogModel
        let source: CatalogSource

        /// The literal for a value.
        ///
        /// - Throws: ``GeneratorError/invalidCatalog(_:)`` when the value can't become a literal, so a broken value
        ///   fails the render instead of vanishing from the code.
        func literal<Value>(_ value: Value, _ field: String, _ make: (Value) -> String?) throws(GeneratorError) -> SwiftExpression {
            guard let literal = make(value) else {
                throw .invalidCatalog("\(source.displayName) model \(model.id) has an invalid \(field): '\(value)'.")
            }
            return .atom(literal)
        }

        /// The literal for a value, or `nil` when the catalog has none.
        func make<Value>(_ value: Value?, _ field: String, _ make: (Value) -> String?) throws(GeneratorError) -> SwiftExpression? {
            try value.map { (value) throws(GeneratorError) in try literal(value, field, make) }
        }

        func price(_ text: String?, _ field: String) throws(GeneratorError) -> SwiftExpression? {
            try make(text, "\(field) price", SwiftLiteral.decimal)
        }
    }

    private static func initializer(
        of model: CatalogModel,
        efforts: [String],
        from source: CatalogSource
    ) throws(GeneratorError) -> SwiftExpression {
        let literals = Literals(model: model, source: source)
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
                "knowledgeCutoff": try literals.make(model.knowledgeCutoff, "knowledge cutoff", SwiftLiteral.date(day:)),
                "expirationDate": try literals.make(model.expirationDate, "expiration date", SwiftLiteral.date(day:)),
                "contextSize": model.contextSize.map { .atom(SwiftLiteral.integer($0)) },
                "maximumOutputTokens": model.maximumOutputTokens.map { .atom(SwiftLiteral.integer($0)) },
                "inputModalities": words(model.inputModalities, unlessEqualTo: ["text"]),
                "outputModalities": words(model.outputModalities, unlessEqualTo: ["text"]),
                "supportedParameters": words(model.supportedParameters, unlessEqualTo: []),
                "reasoning": model.reasoning == .unsupported ? nil : .atom(model.reasoning.swiftLiteral),
                "reasoningEfforts": efforts.isEmpty ? nil : .array(efforts.map(effort)),
                "defaultReasoningEffort": model.defaultReasoningEffort.map(effort),
                "pricing": try model.pricing.map { (pricing) throws(GeneratorError) in try self.pricing(pricing, literals) },
            ]
        )
    }

    private static func pricing(_ pricing: CatalogModel.Pricing, _ literals: Literals) throws(GeneratorError) -> SwiftExpression {
        let overrides = try (pricing.overrides ?? []).map { (override) throws(GeneratorError) in try self.override(override, literals) }
        return .call(
            "OpenRouterPricing",
            [
                "prompt": try literals.price(pricing.prompt, "prompt"),
                "completion": try literals.price(pricing.completion, "completion"),
                "cacheRead": try literals.price(pricing.cacheRead, "cache read"),
                "cacheWrite": try literals.price(pricing.cacheWrite, "cache write"),
                "overrides": overrides.isEmpty ? nil : .array(overrides),
            ]
        )
    }

    private static func override(
        _ override: CatalogModel.Pricing.Override,
        _ literals: Literals
    ) throws(GeneratorError) -> SwiftExpression {
        let days = try override.weekdays.map { (weekdays) throws(GeneratorError) in
            try weekdays.map { (day) throws(GeneratorError) in
                try literals.literal(day, "override day") { Self.weekdays.contains($0) ? ".\($0)" : nil }
            }
        }
        // A window with one end missing runs from or to midnight.
        let hours: SwiftExpression? =
            override.startTime == nil && override.endTime == nil
            ? nil
            : .call(
                ".init",
                [
                    "start": try literals.literal(override.startTime ?? 0, "override start time", SwiftLiteral.duration(clockTime:)),
                    "end": try literals.literal(
                        override.endTime ?? Self.midnightAtEnd,
                        "override end time",
                        SwiftLiteral.duration(clockTime:)
                    ),
                ]
            )
        let condition = SwiftExpression.call(
            ".init",
            [
                "promptTokensAbove": override.promptTokensAbove.map { .atom(SwiftLiteral.integer($0)) },
                "weekdays": days.map { .array($0) },
                "hours": hours,
            ]
        )
        return .call(
            ".init",
            [
                "condition": condition,
                "prompt": try literals.price(override.prompt, "override prompt"),
                "completion": try literals.price(override.completion, "override completion"),
                "cacheRead": try literals.price(override.cacheRead, "override cache read"),
                "cacheWrite": try literals.price(override.cacheWrite, "override cache write"),
            ]
        )
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
}
