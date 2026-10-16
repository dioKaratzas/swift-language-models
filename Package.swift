// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .strictMemorySafety(),
]

let package = Package(
    name: "swift-language-models",
    products: [
        .library(
            name: "LanguageModels",
            targets: ["LanguageModels"]
        ),
    ],
    targets: [
        .target(
            name: "LanguageModels",
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "LanguageModelsTests",
            dependencies: ["LanguageModels"],
            swiftSettings: swiftSettings,
        ),
    ],
    swiftLanguageModes: [.v6]
)
