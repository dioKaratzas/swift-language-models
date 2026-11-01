import Foundation

/// A value of an answer that breaks a constraint of its schema, such as a number below its guide's minimum.
package struct GuideViolation: Equatable, Sendable, CustomStringConvertible {
    /// Where the value is in the answer, such as `ingredients[1].grams`, or empty for the whole answer.
    package let path: String
    /// The schema keyword the value breaks, such as `minimum`.
    package let keyword: String
    /// What's wrong with the value, such as `is 0, below the minimum of 1`.
    package let problem: String

    package init(path: String, keyword: String, problem: String) {
        self.path = path
        self.keyword = keyword
        self.problem = problem
    }

    /// Where the value is and what's wrong with it, such as `ingredients[1].grams is 0, below the minimum of 1`.
    package var description: String {
        "\(path.isEmpty ? "The answer" : path) \(problem)"
    }
}

extension JSONValue {
    /// The constraints of a JSON schema that the value breaks.
    ///
    /// It checks the constraints that guides become, `const`, `enum`, `minimum`, `maximum`, `exclusiveMinimum`,
    /// `exclusiveMaximum`, `minItems`, `maxItems`, `minLength`, `maxLength` and `pattern`, through `properties`,
    /// `items`, `anyOf`, `allOf` and references into `$defs`. Each applies only to values of its kind, and a `pattern`
    /// matches anywhere in the string, by Unicode scalar, as in JSON Schema. Types, and the `const` that names an
    /// enum's case, only choose the `anyOf` branch a value takes: decoding checks them.
    ///
    /// - Parameter schema: The schema, whose `$ref`s point into its own `$defs`.
    /// - Returns: Each broken constraint, in the order of the value; none when the value meets them all.
    package func violations(of schema: JSONValue) -> [GuideViolation] {
        SchemaChecker(root: schema).violations(of: self, against: schema, at: "", depth: 0)
    }
}

/// Checks values against the constraints of one schema.
private struct SchemaChecker {
    let root: JSONValue

    /// How deep references may nest, so a schema that refers to itself ends.
    private static let maximumDepth = 64

    func violations(of value: JSONValue, against schema: JSONValue, at path: String, depth: Int) -> [GuideViolation] {
        guard case .object(let keywords) = schema, depth < Self.maximumDepth else { return [] }
        var found: [GuideViolation] = []
        if let target = keywords["$ref"].flatMap(resolve) {
            found += violations(of: value, against: target, at: path, depth: depth + 1)
        }
        if case .array(let branches)? = keywords["anyOf"] {
            found += violations(of: value, againstAnyOf: branches, at: path, depth: depth)
        }
        if case .array(let branches)? = keywords["allOf"] {
            for branch in branches { found += violations(of: value, against: branch, at: path, depth: depth + 1) }
        }
        found += Self.violations(of: value, keywords: keywords, at: path)
        switch value {
        case .object(let object):
            guard case .object(let properties)? = keywords["properties"] else { break }
            for member in object.members {
                guard let property = properties[member.key] else { continue }
                found += violations(of: member.value, against: property, at: Self.path(path, member.key), depth: depth + 1)
            }
        case .array(let elements):
            guard let items = keywords["items"] else { break }
            for (index, element) in elements.enumerated() {
                found += violations(of: element, against: items, at: "\(path)[\(index)]", depth: depth + 1)
            }
        default:
            break
        }
        return found
    }

    /// A value meets `anyOf` when it meets a branch. Otherwise its violations are those of the first branch of its
    /// type, and none when no branch is of its type, which decoding reports.
    private func violations(of value: JSONValue, againstAnyOf branches: [JSONValue], at path: String, depth: Int) -> [GuideViolation] {
        var firstOfItsType: [GuideViolation]?
        for branch in branches where fits(value, branch, depth: depth + 1) {
            let found = violations(of: value, against: branch, at: path, depth: depth + 1)
            if found.isEmpty { return [] }
            if firstOfItsType == nil { firstOfItsType = found }
        }
        return firstOfItsType ?? []
    }

    /// Whether the value is of a type the schema allows, following references and `anyOf`, and names the case the
    /// schema is for, when the schema is one case of an enum. A schema without a type allows any.
    private func fits(_ value: JSONValue, _ schema: JSONValue, depth: Int) -> Bool {
        guard case .object(let keywords) = schema, depth < Self.maximumDepth else { return true }
        if let target = keywords["$ref"].flatMap(resolve), !fits(value, target, depth: depth + 1) { return false }
        if case .array(let branches)? = keywords["anyOf"], !branches.contains(where: { fits(value, $0, depth: depth + 1) }) {
            return false
        }
        // Each case of an enum with associated values is an object whose `type` property has a `const`, its name.
        if case .object(let object) = value, case .object(let properties)? = keywords["properties"] {
            for property in properties.members {
                guard let name = property.value["const"] else { continue }
                guard let member = object[property.key], member.isSame(as: name) else { return false }
            }
        }
        switch keywords["type"] {
        case .string(let type)?: return value.isOfType(type)
        case .array(let types)?: return types.contains { $0.stringValue.map(value.isOfType) ?? false }
        default: return true
        }
    }

    /// The schema a `$ref` such as `#/$defs/Ingredient` points to.
    private func resolve(_ reference: JSONValue) -> JSONValue? {
        guard let reference = reference.stringValue, reference.hasPrefix("#") else { return nil }
        var target: JSONValue? = root
        for component in reference.dropFirst().split(separator: "/") {
            let key = String(component).replacing("~1", with: "/").replacing("~0", with: "~")
            target = target?[key]
        }
        return target
    }

    /// The violations of the keywords that constrain the value itself.
    private static func violations(of value: JSONValue, keywords: JSONObject, at path: String) -> [GuideViolation] {
        var found: [GuideViolation] = []
        func add(_ keyword: String, _ problem: String) {
            found.append(GuideViolation(path: path, keyword: keyword, problem: problem))
        }
        if let constant = keywords["const"], !value.isSame(as: constant) {
            add("const", "is \(value.shortText), not \(constant.shortText)")
        }
        if case .array(let allowed)? = keywords["enum"], !allowed.contains(where: value.isSame) {
            add("enum", "is \(value.shortText), not one of \(allowed.map(\.shortText).joined(separator: ", "))")
        }
        if let number = value.numberValue {
            if let minimum = keywords["minimum"], let bound = minimum.numberValue, number < bound {
                add("minimum", "is \(value.shortText), below the minimum of \(minimum.shortText)")
            }
            if let maximum = keywords["maximum"], let bound = maximum.numberValue, number > bound {
                add("maximum", "is \(value.shortText), above the maximum of \(maximum.shortText)")
            }
            if let minimum = keywords["exclusiveMinimum"], let bound = minimum.numberValue, number <= bound {
                add("exclusiveMinimum", "is \(value.shortText), not above \(minimum.shortText)")
            }
            if let maximum = keywords["exclusiveMaximum"], let bound = maximum.numberValue, number >= bound {
                add("exclusiveMaximum", "is \(value.shortText), not below \(maximum.shortText)")
            }
        }
        if case .array(let elements) = value {
            if let minimum = keywords["minItems"]?.numberValue, Double(elements.count) < minimum {
                add("minItems", "has \(items(elements.count)), fewer than the minimum of \(Int(minimum))")
            }
            if let maximum = keywords["maxItems"]?.numberValue, Double(elements.count) > maximum {
                add("maxItems", "has \(items(elements.count)), more than the maximum of \(Int(maximum))")
            }
        }
        if case .string(let text) = value {
            let length = Double(text.unicodeScalars.count)
            if let minimum = keywords["minLength"]?.numberValue, length < minimum {
                add("minLength", "is \(value.shortText), shorter than the minimum of \(Int(minimum)) characters")
            }
            if let maximum = keywords["maxLength"]?.numberValue, length > maximum {
                add("maxLength", "is \(value.shortText), longer than the maximum of \(Int(maximum)) characters")
            }
            // A pattern Swift can't compile is left unchecked, rather than failing an answer the host accepted.
            if let pattern = keywords["pattern"]?.stringValue, let regex = try? Regex(pattern).matchingSemantics(.unicodeScalar),
                text.firstMatch(of: regex) == nil
            {
                add("pattern", "is \(value.shortText), which doesn't match the pattern \(pattern)")
            }
        }
        return found
    }

    private static func path(_ path: String, _ key: String) -> String {
        path.isEmpty ? key : "\(path).\(key)"
    }

    private static func items(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }
}

extension JSONValue {
    /// The value as a number, for any of the number cases.
    fileprivate var numberValue: Double? {
        switch self {
        case .integer(let value): Double(value)
        case .largeInteger(let value): NSDecimalNumber(decimal: value).doubleValue
        case .number(let value): value
        default: nil
        }
    }

    /// Whether the value is of a JSON Schema type, where a whole number is an `integer` too.
    fileprivate func isOfType(_ type: String) -> Bool {
        switch (type, self) {
        case ("null", .null), ("boolean", .bool), ("string", .string), ("array", .array), ("object", .object): true
        case ("integer", .integer), ("integer", .largeInteger): true
        case ("integer", .number(let value)): value.rounded() == value
        case ("number", _): numberValue != nil
        default: false
        }
    }

    /// Whether two values are the same JSON value, where numbers compare by value.
    fileprivate func isSame(as other: JSONValue) -> Bool {
        if let number = numberValue, let otherNumber = other.numberValue { return number == otherNumber }
        return self == other
    }

    /// The value as JSON text, cut short after 60 characters.
    fileprivate var shortText: String {
        let text = self.text
        return text.count > 60 ? "\(text.prefix(60))…" : text
    }
}
