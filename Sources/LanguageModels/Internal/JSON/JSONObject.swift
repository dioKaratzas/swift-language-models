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

    /// The object with its members sorted by key, which gives the same bytes however it was built.
    package func sortedByKey() -> JSONObject {
        sorted { $0.key < $1.key }
    }
}

extension JSONObject: ExpressibleByDictionaryLiteral {
    /// An object with the members that have a value, in the order written, so an optional field can be `nil`.
    package init(dictionaryLiteral elements: (String, JSONValue?)...) {
        self.init(optionalMembers: elements)
    }

    init(optionalMembers elements: [(String, JSONValue?)]) {
        self.init(elements.compactMap { key, value in value.map { Member(key: key, value: $0) } })
    }
}
