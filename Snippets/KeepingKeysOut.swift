// snippet.hide
import CryptoKit
import DeviceCheck
import Foundation
import OpenRouterLanguageModels
import Security

// snippet.show
// snippet.keychain
/// A secret kept in the Keychain on this device only, such as a key the person pastes.
struct KeychainItem: Sendable {
    let service: String
    let account: String

    @concurrent func save(_ secret: String) async throws {
        let attributes: [CFString: Any] = [
            kSecValueData: Data(secret.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    @concurrent func read() async throws -> String? {
        let search = query.merging([kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]) { $1 }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(search as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return String(decoding: data, as: UTF8.self)
    }

    @concurrent func delete() async throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private var query: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
        ]
    }
}

struct KeychainError: Error {
    let status: OSStatus
}
// snippet.end

// snippet.appAttest
/// A short-lived token from your server, which issues one after App Attest proves the request comes from your app.
actor AppToken {
    let server: URL
    private let keyID = KeychainItem(service: "app-attest", account: "key-id")
    private var current: (value: String, expires: Date)?
    private var refreshing: Task<Issued, any Error>?

    init(server: URL) {
        self.server = server
    }

    func value() async throws -> String {
        if let current, current.expires.timeIntervalSinceNow > 60 { return current.value }
        // Requests that start together wait for one new token, instead of each attesting a key.
        let task = refreshing ?? Task { try await issue() }
        refreshing = task
        defer { refreshing = nil }
        let issued = try await task.value
        current = (issued.token, .now.addingTimeInterval(issued.expiresIn))
        return issued.token
    }

    private func issue() async throws -> Issued {
        guard DCAppAttestService.shared.isSupported else { throw DCError(.featureUnsupported) }
        let challenge = try await post("challenge", [:], as: Challenge.self).challenge
        let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        if let id = try await keyID.read() {
            do {
                let assertion = try await DCAppAttestService.shared.generateAssertion(id, clientDataHash: clientDataHash)
                let body = ["keyID": id, "challenge": challenge, "assertion": assertion.base64EncodedString()]
                return try await post("assert", body, as: Issued.self)
            } catch DCError.invalidKey {
                // The key doesn't survive a reinstall or a restore, so attest a new one.
                try await keyID.delete()
                return try await issue()
            }
        }
        let id = try await DCAppAttestService.shared.generateKey()
        let attestation = try await DCAppAttestService.shared.attestKey(id, clientDataHash: clientDataHash)
        let body = ["keyID": id, "challenge": challenge, "attestation": attestation.base64EncodedString()]
        let issued = try await post("attest", body, as: Issued.self)
        try await keyID.save(id)
        return issued
    }

    private func post<Response: Decodable>(_ path: String, _ body: [String: String], as: Response.Type) async throws -> Response {
        var request = URLRequest(url: server.appending(path: "app-attest/\(path)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.userAuthenticationRequired) }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private struct Challenge: Decodable {
        let challenge: String
    }

    private struct Issued: Decodable {
        let token: String
        let expiresIn: TimeInterval
    }
}
// snippet.end

// snippet.hide
func proxied(server: URL) {
    // snippet.show
    // snippet.proxied
    let token = AppToken(server: server)
    let model = OpenRouterLanguageModel(
        .anthropicClaudeHaiku5_5,
        auth: .proxied(baseURL: server.appending(path: "openrouter/")) {
            ["X-App-Token": try await token.value()]
        }
    )
    // snippet.end
    // snippet.hide
    _ = model
}
