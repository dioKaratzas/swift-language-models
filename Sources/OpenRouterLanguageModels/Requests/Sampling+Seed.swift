import Foundation
import LanguageModels

extension Sampling {
    /// A seed as a number that hosts read as a signed 64-bit integer. A seed of 2^63 or more loses its top bit, so every
    /// seed is sent, and each one as the same number on every platform.
    static func json(seed: UInt64) -> JSONValue {
        let folded = seed & UInt64(Int64.max)
        return Int(exactly: folded).map(JSONValue.integer) ?? .largeInteger(Decimal(folded))
    }
}
