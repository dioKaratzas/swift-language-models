import Foundation
import Synchronization

/// A tour of swift-language-models in the terminal, one command for each feature.
///
/// ```
/// showcase                          Asks for the API key, then shows a menu of the commands until Return.
/// showcase <command> [arguments]    Runs one command, such as `showcase chat` or `showcase catalog vision`.
/// showcase help                     Lists the commands and their arguments.
/// ```
///
/// Every command but `catalog` and `providers` calls OpenRouter with the API key in the `OPENROUTER_API_KEY`
/// environment variable, or the one typed when the showcase asks for it. `providers` sends the key when there is one.
@main
struct Showcase {
    /// The commands, in the order the menu lists them.
    static let commands: [any Command] = [
        Chat(), Tools(), Guided(), Reasoning(), Search(), Fallbacks(), Caching(), Attachments(), Profiles(), Catalog(),
        Providers(),
    ]

    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty {
            await showMenuUntilReturn()
        } else {
            exit(await run(arguments) ? 0 : 1)
        }
    }

    /// Asks for the key once, then shows the menu again after each command, until Return or the end of the input.
    static func showMenuUntilReturn() async {
        if openRouterKey().isEmpty, Terminal.isInteractive {
            print(Style.dim("Paste your OpenRouter API key. Return skips it; only catalog and providers work without one."))
            _ = askForKey()
        }
        while true {
            showMenu()
            guard let line = Terminal.ask("› "), !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            _ = await run(Terminal.words(in: line))
            print()
        }
    }

    /// Runs the command the first word names, with the other words as its arguments.
    ///
    /// - Returns: Whether the command ran and finished without an error.
    static func run(_ words: [String]) async -> Bool {
        guard let word = words.first else { return false }
        guard let command = command(named: word) else {
            if word != "help" { Terminal.printError("There's no command \(word).\n") }
            showHelp()
            return word == "help"
        }
        if command.needsKey, openRouterKey().isEmpty, !askForKey() {
            Terminal.printError(missingKey)
            return false
        }
        do {
            try await command.run(Array(words.dropFirst()))
            return true
        } catch {
            Terminal.report(error)
            return false
        }
    }

    /// The command with the given name, or number in the menu.
    static func command(named word: String) -> (any Command)? {
        if let number = Int(word), commands.indices.contains(number - 1) {
            return commands[number - 1]
        }
        return commands.first { $0.name == word }
    }

    static func showMenu() {
        print(Style.bold("swift-language-models showcase") + "\n")
        for (index, command) in commands.enumerated() {
            print(String(format: "%3d  ", index + 1) + command.name.padded(to: 14) + command.summary)
        }
        print("\nType a number or a name, and any arguments, such as \(Style.bold("catalog vision")).")
        print("Each command comes back to this menu. Return quits.")
    }

    static func showHelp() {
        print("Usage: showcase <command> [arguments]\n")
        for command in commands {
            print("  " + "\(command.name) \(command.usage)".padded(to: 32) + command.summary)
        }
        print("\nWithout a command, showcase shows a menu. Every command but catalog and providers needs OPENROUTER_API_KEY.")
    }

    /// Asks for the API key with the typing hidden, when the showcase runs in a terminal, and keeps it for this run.
    ///
    /// - Returns: Whether a key was entered. Xcode's console can't hide typing, so there the showcase never asks.
    static func askForKey() -> Bool {
        guard isatty(STDIN_FILENO) == 1, Terminal.isInteractive,
            let key = Terminal.askHidden("OpenRouter API key (typing is hidden): "), !key.isEmpty
        else { return false }
        enteredKey.withLock { $0 = key }
        return true
    }

    static let missingKey = """
        This command calls OpenRouter, so it needs an API key. Create one at https://openrouter.ai/keys, then:

          In a terminal:  run the showcase and paste the key when it asks, or export OPENROUTER_API_KEY=<your key>
          In Xcode:       Product > Scheme > Edit Scheme > Run > Arguments, and add OPENROUTER_API_KEY under
                          Environment Variables. Leave the scheme unshared, so the key stays out of git.
        """
}

/// A feature that `showcase <name>` runs.
protocol Command: Sendable {
    /// The word that runs the command.
    var name: String { get }

    /// What the command shows, in a line for the menu.
    var summary: String { get }

    /// The arguments the command takes, for the help, such as `[question]`.
    var usage: String { get }

    /// Whether the command calls OpenRouter, which needs an API key.
    var needsKey: Bool { get }

    /// Runs the command with the arguments that follow its name.
    func run(_ arguments: [String]) async throws
}

extension Command {
    var usage: String { "" }
    var needsKey: Bool { true }
}

extension [String] {
    /// The arguments as one text, or a fallback when there are none.
    func text(or fallback: String) -> String {
        isEmpty ? fallback : joined(separator: " ")
    }
}

/// The key typed when the showcase asked for it, kept in memory for this run only.
let enteredKey = Mutex<String?>(nil)

/// Returns the OpenRouter API key, for each request a model sends: `OPENROUTER_API_KEY` from the environment, or the
/// key typed when the showcase asked for it.
///
/// Both suit development only. An app never ships a key, where anyone can extract it: it lets people enter their own
/// and keeps it in the Keychain, or sends requests through its own server.
func openRouterKey() -> String {
    if let key = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !key.isEmpty {
        return key
    }
    return enteredKey.withLock { $0 } ?? ""
}
