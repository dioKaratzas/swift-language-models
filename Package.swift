// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
    .strictMemorySafety(),
]

let providers = ["OpenRouter", "Anthropic", "OpenAI"]

func provider(_ name: String) -> [Target] {
    [
        .target(
            name: "\(name)LanguageModels",
            dependencies: ["LanguageModels"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "\(name)LanguageModelsTests",
            dependencies: [.target(name: "\(name)LanguageModels"), "LanguageModelsTesting"],
            swiftSettings: swiftSettings
        ),
    ]
}

let package = Package(
    name: "swift-language-models",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .visionOS(.v27),
        .watchOS(.v27),
    ],
    products: [
        .library(name: "LanguageModels", targets: ["LanguageModels"])
    ]
        + providers.map {
            .library(name: "\($0)LanguageModels", targets: ["\($0)LanguageModels"])
        },
    targets: [
        .target(
            name: "LanguageModels",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "LanguageModelsTesting",
            dependencies: ["LanguageModels"],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "ModelCatalogGenerator",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ModelCatalogGeneratorTests",
            dependencies: ["ModelCatalogGenerator"],
            swiftSettings: swiftSettings
        ),
    ]
        + providers.flatMap(provider),
    swiftLanguageModes: [.v6]
)
