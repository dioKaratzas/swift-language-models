import Foundation
package import Testing

/// A trait that runs a test only when an environment variable holds an API key, and binds that key to
/// ``current`` while the test runs.
package struct APIKeyTrait: TestTrait, SuiteTrait, TestScoping {
    /// The key that the trait read for the running test, or `nil` outside such a test.
    ///
    /// Read it while the test runs, for example when building a model, and capture the value: Foundation Models may
    /// call a model's key closure from a task of its own, where this value isn't bound.
    @TaskLocal package static var current: String?

    /// The environment variable that holds the key, such as `OPENROUTER_API_KEY`.
    let variable: String

    package var isRecursive: Bool { true }

    /// The key, or `nil` when the variable is missing or empty.
    private var key: String? {
        ProcessInfo.processInfo.environment[variable].flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Why a test without the key doesn't run.
    private var missingKeyReason: Comment { "Set \(variable) to run this test" }

    package func prepare(for test: Test) async throws {
        // A condition trait's skip, so a suite without the key shows as skipped rather than as cancelled tests.
        try await ConditionTrait.enabled(if: key != nil, missingKeyReason).prepare(for: test)
    }

    package func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        testCase == nil ? nil : self
    }

    // Testing declares the requirement without nonisolated(nonsending), so both the method and its closure run
    // concurrently.
    @concurrent package func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable @concurrent () async throws -> Void
    ) async throws {
        guard let key else { try Test.cancel(missingKeyReason) }
        try await Self.$current.withValue(key) { try await function() }
    }
}

extension Trait where Self == APIKeyTrait {
    /// Runs the test only when an environment variable holds an API key, with the key in ``APIKeyTrait/current``.
    ///
    /// - Parameter variable: The environment variable, such as `OPENROUTER_API_KEY`.
    /// - Returns: A trait that skips the test when the variable is missing or empty.
    package static func requiresAPIKey(_ variable: String) -> Self {
        Self(variable: variable)
    }
}
