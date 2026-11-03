// snippet.hide
import Foundation
import FoundationModels
import OpenAILanguageModels

func key() {
    // snippet.show
    // snippet.key
    let model = OpenAILanguageModel(.gpt6Luna, auth: .apiKey { try await keyStore.openAIKey() })
    // snippet.end
    // snippet.hide
    _ = model
}

func organization(organizationID: String, projectID: String) {
    // snippet.show
    // snippet.organization
    let model = OpenAILanguageModel(
        .gpt6Luna,
        auth: .apiKey(organization: organizationID, project: projectID) { try await keyStore.openAIKey() }
    )
    // snippet.end
    // snippet.hide
    _ = model
}

func proxy(account: Account) {
    // swift-format-ignore: NeverForceUnwrap
    // snippet.show
    // snippet.proxy
    let model = OpenAILanguageModel(
        .gpt6Luna,
        auth: .proxied(
            baseURL: URL(string: "https://api.yourapp.com/openai/")!,
            headers: { ["X-App-Token": try await account.appToken()] }
        )
    )
    // snippet.end
    // snippet.hide
    _ = model
}

/// Stands in for the app's signed-in account.
struct Account: Sendable {
    func appToken() async throws -> String { "" }
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openAIKey() async throws -> String { "" }
}

let keyStore = KeyStore()
