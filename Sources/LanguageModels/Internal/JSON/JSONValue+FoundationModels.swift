import Foundation
package import FoundationModels

extension JSONValue {
    /// Generated content as JSON, with each structure's properties sorted by name.
    ///
    /// A structure parsed from JSON doesn't keep its key order between launches, so sorting is what makes the same
    /// content give the same bytes.
    package init(_ content: GeneratedContent) {
        switch content.kind {
        case .null: self = .null
        case .bool(let value): self = .bool(value)
        case .number(let value): self = .number(value)
        case .string(let value): self = .string(value)
        case .array(let elements): self = .array(elements.map(JSONValue.init))
        case .structure(let properties, _):
            self = .object(
                JSONObject(properties.map { JSONObject.Member(key: $0.key, value: JSONValue($0.value)) }).sorted { $0.key < $1.key }
            )
        @unknown default: self = .string(content.jsonString)
        }
    }

    /// A schema as JSON Schema, with its properties in generation order.
    ///
    /// Foundation Models lists the order in `x-order`, which providers don't know, so the properties take that order
    /// and the key is dropped.
    ///
    /// - Parameter strict: Whether to apply structured-output strict mode: every property is required, and an
    ///   optional one also accepts `null`.
    /// - Throws: An error when the schema can't be encoded.
    package init(_ schema: GenerationSchema, strict: Bool) throws {
        self = try JSONValue(json: JSONEncoder().encode(schema)).adaptedSchema(strict: strict)
    }

    private func adaptedSchema(strict: Bool) -> JSONValue {
        switch self {
        case .array(let elements):
            return .array(elements.map { $0.adaptedSchema(strict: strict) })
        case .object(var object):
            let order = object["x-order"].flatMap(\.stringArray) ?? []
            object["x-order"] = nil
            if case .object(let properties)? = object["properties"] {
                let required = Set(object["required"].flatMap(\.stringArray) ?? [])
                let position = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
                let ordered = properties.sorted { position[$0.key, default: .max] < position[$1.key, default: .max] }
                object["properties"] = .object(
                    JSONObject(
                        ordered.members.map { member in
                            let schema = member.value.adaptedSchema(strict: strict)
                            let isOptional = strict && !required.contains(member.key)
                            return JSONObject.Member(key: member.key, value: isOptional ? ["anyOf": [schema, ["type": "null"]]] : schema)
                        }
                    )
                )
                if strict { object["required"] = .array(ordered.members.map { .string($0.key) }) }
            }
            return .object(
                JSONObject(
                    object.members.map { member in
                        member.key == "properties"
                            ? member : JSONObject.Member(key: member.key, value: member.value.adaptedSchema(strict: strict))
                    }
                )
            )
        default:
            return self
        }
    }

    private var stringArray: [String]? {
        guard case .array(let elements) = self else { return nil }
        return elements.compactMap(\.stringValue)
    }
}
