import Synchronization

/// How much the package writes to the unified logging system.
///
/// The package logs what each request sends, what it leaves out or changes from what the app asked for, retries,
/// which model and host answered, failures, and how long each request took. Every message has the subsystem
/// `com.niosoft.swift-language-models` and a category for each provider, such as `OpenRouter`.
///
/// It never logs API keys, prompts, answers, tool arguments or outputs, or attachments. This covers the package's own
/// logging: a recording with Instruments' Foundation Models template can include prompts and responses, which
/// Foundation Models records. Model ids, host names, parameter names, HTTP statuses, error codes and timings are
/// public; a host's error message is private, since it may quote the request.
///
/// Logging is on at every level, and the system decides what it keeps, as it does for Apple's frameworks: debug
/// messages only while a tool such as Xcode or Console shows them, info messages only in memory, and errors on disk.
/// Set a level once, early, to log less:
///
/// ```swift
/// import OpenRouterLanguageModels  // Or any provider's module, each of which re-exports this one.
///
/// LanguageModelsLogging.level = .error  // Only failed requests.
/// LanguageModelsLogging.level = .off  // Nothing.
/// ```
public enum LanguageModelsLogging {
    /// The least severe messages the package logs, or ``Level/off`` to log nothing. The default is ``Level/debug``,
    /// every message.
    ///
    /// Any thread can read and set it.
    public static var level: Level {
        get { Level(rawValue: storedLevel.load(ordering: .relaxed)) ?? .debug }
        set { storedLevel.store(newValue.rawValue, ordering: .relaxed) }
    }

    /// The subsystem of every message the package logs.
    package static let subsystem = "com.niosoft.swift-language-models"

    private static let storedLevel = Atomic(Level.debug.rawValue)
}

extension LanguageModelsLogging {
    /// How severe a message is: the unified logging system's levels, from the least severe, then `off`.
    public enum Level: Int, Sendable, Comparable {
        /// Details for debugging: what each request sends, which model and host answered, and how long it took. The
        /// system keeps them only while a tool shows them.
        case debug

        /// Help for troubleshooting: what a request left out or changed from what the app asked for, and retries. The
        /// system keeps them in memory, and on disk only when the `log` tool collects them.
        case info

        /// What's essential for troubleshooting. The system keeps it on disk, up to a limit.
        case notice

        /// Failed requests. The system keeps them on disk, up to a limit.
        case error

        /// Bugs. The system keeps them on disk, up to a limit.
        case fault

        /// No messages at all.
        case off

        /// Whether a level is less severe than another.
        ///
        /// - Parameters:
        ///   - lhs: A level.
        ///   - rhs: Another level.
        /// - Returns: `true` when `lhs` comes before `rhs`, from ``debug`` to ``off``.
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
