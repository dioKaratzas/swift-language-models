package import Foundation

/// A JSON value that writes the same bytes every time.
///
/// Providers reuse a cached prompt only when the request starts with the same bytes as before, and `JSONEncoder`
/// orders keys differently on every launch. Objects built in code keep the order they're written in; objects decoded
/// from JSON are sorted by key, so they come out the same however they arrived.
package enum JSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case integer(Int)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object(JSONObject)

    /// The value's JSON text.
    package var data: Data {
        var text = ""
        write(to: &text)
        return Data(text.utf8)
    }

    /// The member with the given key, when the value is an object.
    package subscript(key: String) -> JSONValue? {
        if case .object(let object) = self { object[key] } else { nil }
    }

    /// The element at an index, when the value is an array that long.
    package subscript(index: Int) -> JSONValue? {
        if case .array(let elements) = self, elements.indices.contains(index) { elements[index] } else { nil }
    }

    /// The text, when the value is a string.
    package var stringValue: String? {
        if case .string(let text) = self { text } else { nil }
    }

    private func write(to text: inout String) {
        switch self {
        case .null: text += "null"
        case .bool(let value): text += value ? "true" : "false"
        case .integer(let value): text += String(value)
        case .number(let value): text += Self.text(of: value)
        case .string(let value): Self.write(value, to: &text)
        case .array(let elements):
            text += "["
            for (index, element) in elements.enumerated() {
                if index > 0 { text += "," }
                element.write(to: &text)
            }
            text += "]"
        case .object(let object):
            text += "{"
            for (index, member) in object.members.enumerated() {
                if index > 0 { text += "," }
                Self.write(member.key, to: &text)
                text += ":"
                member.value.write(to: &text)
            }
            text += "}"
        }
    }

    /// A number without a fraction as an integer, and any other number in its shortest exact form. JSON has no
    /// infinity or NaN, so those become `null`.
    private static func text(of number: Double) -> String {
        guard number.isFinite else { return "null" }
        if number.rounded() == number, let integer = Int(exactly: number) { return String(integer) }
        return number.description
    }

    private static func write(_ string: String, to text: inout String) {
        text += "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": text += "\\\""
            case "\\": text += "\\\\"
            case "\n": text += "\\n"
            case "\r": text += "\\r"
            case "\t": text += "\\t"
            case "\u{08}": text += "\\b"
            case "\u{0C}": text += "\\f"
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                text += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default: text.unicodeScalars.append(scalar)
            }
        }
        text += "\""
    }
}

/// A JSON object whose members keep their order when written.
package struct JSONObject: Sendable, Equatable {
    package struct Member: Sendable, Equatable {
        package let key: String
        package var value: JSONValue

        package init(key: String, value: JSONValue) {
            self.key = key
            self.value = value
        }
    }

    package private(set) var members: [Member]

    package init(_ members: [Member] = []) {
        self.members = members
    }

    /// The value of the first member with the given key.
    package subscript(key: String) -> JSONValue? {
        get { members.first { $0.key == key }?.value }
        set {
            if let index = members.firstIndex(where: { $0.key == key }) {
                if let newValue { members[index].value = newValue } else { members.remove(at: index) }
            } else if let newValue {
                members.append(Member(key: key, value: newValue))
            }
        }
    }

    /// Whether two objects have the same members, in any order, as JSON objects are compared.
    package static func == (lhs: JSONObject, rhs: JSONObject) -> Bool {
        lhs.members.count == rhs.members.count && lhs.members.allSatisfy { rhs[$0.key] == $0.value }
    }

    /// The object with its members in a new order.
    package func sorted(by areInIncreasingOrder: (Member, Member) -> Bool) -> JSONObject {
        JSONObject(members.sorted(by: areInIncreasingOrder))
    }
}

extension JSONObject: ExpressibleByDictionaryLiteral {
    /// An object with the members that have a value, in the order written, so an optional field can be `nil`.
    package init(dictionaryLiteral elements: (String, JSONValue?)...) {
        self.init(optionalMembers: elements)
    }

    fileprivate init(optionalMembers elements: [(String, JSONValue?)]) {
        self.init(elements.compactMap { key, value in value.map { Member(key: key, value: $0) } })
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral, ExpressibleByStringLiteral,
    ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral
{
    package init(dictionaryLiteral elements: (String, JSONValue?)...) {
        self = .object(JSONObject(optionalMembers: elements))
    }

    package init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }

    package init(stringLiteral value: String) {
        self = .string(value)
    }

    package init(integerLiteral value: Int) {
        self = .integer(value)
    }

    package init(floatLiteral value: Double) {
        self = .number(value)
    }

    package init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: Decodable {
    /// Decodes any JSON value, with each object's members sorted by key.
    package init(from decoder: any Decoder) throws {
        if let container = try? decoder.container(keyedBy: AnyCodingKey.self) {
            let members = try container.allKeys.map { key in
                JSONObject.Member(key: key.stringValue, value: try container.decode(JSONValue.self, forKey: key))
            }
            self = .object(JSONObject(members).sorted { $0.key < $1.key })
        } else if var container = try? decoder.unkeyedContainer() {
            var elements: [JSONValue] = []
            while !container.isAtEnd { elements.append(try container.decode(JSONValue.self)) }
            self = .array(elements)
        } else {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Int.self) {
                self = .integer(value)
            } else if let value = try? container.decode(Double.self) {
                self = .number(value)
            } else {
                self = .string(try container.decode(String.self))
            }
        }
    }

    /// Decodes JSON text.
    package init(json data: Data) throws {
        self = try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

/// A coding key for any member name.
private struct AnyCodingKey: CodingKey {
    let stringValue: String

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int? { nil }

    init?(intValue: Int) {
        nil
    }
}
