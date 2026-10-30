import CryptoKit
import Foundation
import Synchronization

/// Recent answers of OpenRouter's info calls, kept in memory so repeated calls, such as one for each row of a list,
/// don't fetch them again.
///
/// An answer is kept by its URL and a digest of the key that fetched it, never the key itself, since some answers depend
/// on the account. Failures aren't kept.
final class InfoCache: Sendable {
    /// The cache that every call shares.
    static let shared = InfoCache()

    /// What an answer is kept by.
    struct Key: Hashable, Sendable {
        let url: URL

        /// The SHA-256 digest of the key that fetched the answer, or `nil` for a call without a key.
        let account: String?

        init(url: URL, apiKey: String?) {
            self.url = url
            account = apiKey.map { SHA256.hash(data: Data($0.utf8)).description }
        }
    }

    private struct Entry: Sendable {
        let value: any Sendable
        let expiry: ContinuousClock.Instant
    }

    private let entries = Mutex<[Key: Entry]>([:])

    /// The answer kept for a key, or `nil` when there's none or it expired.
    func value<Value: Sendable>(for key: Key, as type: Value.Type, now: ContinuousClock.Instant = .now) -> Value? {
        entries.withLock { entries in
            guard let entry = entries[key] else { return nil }
            guard entry.expiry > now else {
                entries[key] = nil
                return nil
            }
            return entry.value as? Value
        }
    }

    /// Keeps an answer for a while, and drops every answer that expired.
    ///
    /// - Parameters:
    ///   - value: The decoded answer.
    ///   - key: What the answer is kept by.
    ///   - lifetime: How long to keep it; zero or less keeps nothing.
    ///   - now: The time the lifetime counts from.
    func store(_ value: some Sendable, for key: Key, lifetime: Duration, now: ContinuousClock.Instant = .now) {
        guard lifetime > .zero else { return }
        entries.withLock { entries in
            entries = entries.filter { $0.value.expiry > now }
            entries[key] = Entry(value: value, expiry: now + lifetime)
        }
    }
}
