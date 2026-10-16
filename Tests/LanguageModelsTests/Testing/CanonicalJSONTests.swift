import LanguageModelsTesting
import Testing

@Suite("Canonical JSON")
struct CanonicalJSONTests {
    @Test func `key order and spacing don't change the canonical form`() throws {
        #expect(try canonicalJSON(#"{"b":1,"a":[true,null]}"#) == canonicalJSON(#"{ "a": [true, null], "b": 1 }"#))
    }

    @Test func `different values keep different canonical forms`() throws {
        #expect(try canonicalJSON(#"{"a":1}"#) != canonicalJSON(#"{"a":2}"#))
    }

    @Test func `invalid JSON throws`() {
        #expect(throws: (any Error).self) {
            try canonicalJSON("{")
        }
    }
}
