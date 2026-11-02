public import LanguageModels

/// A category of OpenRouter's app marketplace, such as `cli-agent` or `general-chat`.
///
/// OpenRouter takes only the categories it lists, and drops any other without an error.
public struct OpenRouterAppCategory: ProviderVocabulary {
    /// A coding assistant that runs in the terminal.
    public static let cliAgent: Self = "cli-agent"

    /// An editor or IDE integration.
    public static let ideExtension: Self = "ide-extension"

    /// A coding agent that runs in the cloud.
    public static let cloudAgent: Self = "cloud-agent"

    /// A programming app.
    public static let programmingApp: Self = "programming-app"

    /// A builder of mobile and desktop apps.
    public static let nativeAppBuilder: Self = "native-app-builder"

    /// A creative writing tool.
    public static let creativeWriting: Self = "creative-writing"

    /// An app that generates video.
    public static let videoGeneration: Self = "video-gen"

    /// An app that generates images.
    public static let imageGeneration: Self = "image-gen"

    /// An app that generates audio.
    public static let audioGeneration: Self = "audio-gen"

    /// A writing assistant.
    public static let writingAssistant: Self = "writing-assistant"

    /// A general chat app.
    public static let generalChat: Self = "general-chat"

    /// A personal agent.
    public static let personalAgent: Self = "personal-agent"

    /// A legal tool or assistant.
    public static let legal: Self = "legal"

    /// A roleplay app, or another app for chatting with characters.
    public static let roleplay: Self = "roleplay"

    /// A game or other interactive entertainment.
    public static let game: Self = "game"

    /// The category's name in OpenRouter's API.
    public let rawValue: String

    /// Creates a category from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"cli-agent"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
