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

// Each provider is a module named `<Name>LanguageModels`, with its own library product and test target. Adding a
// provider's name here creates them; the module depends only on, and re-exports, `LanguageModels`.
let providers = ["OpenRouter"]

func provider(_ name: String) -> [Target] {
    [
        .target(
            name: "\(name)LanguageModels",
            dependencies: ["LanguageModels"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "\(name)LanguageModelsTests",
            dependencies: [.target(name: "\(name)LanguageModels"), "LanguageModelsTestSupport"],
            resources: [.copy("Fixtures")],
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
        .testTarget(
            name: "LanguageModelsTests",
            dependencies: ["LanguageModels", "LanguageModelsTestSupport"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "LanguageModelsTestSupport",
            dependencies: ["LanguageModels"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "LanguageModelsTestSupportTests",
            dependencies: ["LanguageModelsTestSupport"],
            resources: [.copy("Fixtures")],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "ModelCatalogGenerator",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ModelCatalogGeneratorTests",
            dependencies: ["ModelCatalogGenerator", "LanguageModelsTestSupport"],
            resources: [.copy("Fixtures")],
            swiftSettings: swiftSettings
        ),
        .plugin(
            name: "GenerateModelCatalog",
            capability: .command(
                intent: .custom(
                    verb: "generate-model-catalog",
                    description: "Download the providers' model lists and regenerate the typed model data"
                ),
                permissions: [
                    .allowNetworkConnections(scope: .all(ports: [443]), reason: "Download the providers' model lists"),
                    .writeToPackageDirectory(reason: "Update Catalogs/ and the generated Swift sources"),
                ]
            ),
            dependencies: ["ModelCatalogGenerator"]
        ),
    ]
        + providers.flatMap(provider),
    swiftLanguageModes: [.v6]
)
