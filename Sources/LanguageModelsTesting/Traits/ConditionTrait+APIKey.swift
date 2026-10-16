import Foundation
package import Testing

extension Trait where Self == ConditionTrait {
    /// Runs the test only when an environment variable holds an API key.
    ///
    /// - Parameter variable: The environment variable, such as `OPENROUTER_API_KEY`.
    /// - Returns: A trait that skips the test when the variable is missing or empty.
    package static func requiresAPIKey(_ variable: String) -> Self {
        .enabled(
            if: ProcessInfo.processInfo.environment[variable]?.isEmpty == false,
            "Set \(variable) to run this test"
        )
    }
}
