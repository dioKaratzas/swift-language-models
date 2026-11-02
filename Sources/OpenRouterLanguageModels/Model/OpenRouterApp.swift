public import Foundation

/// How requests name the app to OpenRouter, which credits the app's usage in its rankings and app marketplace.
///
/// Each setting goes in a header of every request, and one left unset sends nothing:
///
/// ```swift
/// let model = OpenRouterLanguageModel(
///     .openaiGpt5Mini,
///     app: OpenRouterApp(name: "Trip Planner", url: URL(string: "https://example.com"), categories: [.personalAgent]),
///     auth: .apiKey { try await keyStore.openRouterKey() }
/// )
/// ```
public struct OpenRouterApp: Sendable, Hashable {
    /// The app's name, shown in OpenRouter's rankings.
    public var name: String?

    /// The app's website, which OpenRouter's rankings link to, and which names the app OpenRouter creates for it.
    public var url: URL?

    /// Up to two of OpenRouter's marketplace categories for the app, such as `.cliAgent`. Any after the second are left
    /// out.
    public var categories: [OpenRouterAppCategory]

    /// Whether the app OpenRouter creates for ``url`` stays out of its public rankings and marketplace, while its usage
    /// still shows in the account's analytics.
    ///
    /// It applies only to the request that creates the app, so it can't hide or show an app that already exists.
    public var isHidden: Bool

    /// Creates the settings that name the app.
    ///
    /// - Parameters:
    ///   - name: The app's name, shown in OpenRouter's rankings.
    ///   - url: The app's website, which OpenRouter's rankings link to.
    ///   - categories: Up to two of OpenRouter's marketplace categories for the app, such as `.cliAgent`.
    ///   - isHidden: Whether the app OpenRouter creates for `url` stays out of its public rankings and marketplace.
    public init(name: String? = nil, url: URL? = nil, categories: [OpenRouterAppCategory] = [], isHidden: Bool = false) {
        self.name = name
        self.url = url
        self.categories = categories
        self.isHidden = isHidden
    }
}
