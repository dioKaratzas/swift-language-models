import Foundation

/// A tour of swift-language-models in the terminal, one command for each feature.
///
/// ```
/// showcase                          Shows a menu of the commands.
/// showcase <command> [arguments]    Runs a command, such as `showcase chat` or `showcase catalog vision`.
/// showcase help                     Lists the commands and their arguments.
/// ```
///
/// Every command but `catalog` calls OpenRouter with the API key in the `OPENROUTER_API_KEY` environment variable.
@main
struct Showcase {
    /// The commands, in the order the menu lists them.
    static let commands: [any Command] = [
        Chat(), Tools(), Guided(), Reasoning(), Search(), Fallbacks(), Caching(), Attachments(), Profiles(), Catalog(),
    ]

    static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty {
            showMenu()
            arguments = Terminal.ask("› ")?.split(separator: " ").map(String.init) ?? []
        }
        guard let word = arguments.first else { return }
        guard let command = command(named: word) else {
            if word != "help" { Terminal.printError("There's no command \(word).\n") }
            showHelp()
            exit(word == "help" ? 0 : 1)
        }
        if command.needsKey, openRouterKey().isEmpty {
            Terminal.printError(missingKey)
            exit(1)
        }

        do {
            try await command.run(Array(arguments.dropFirst()))
        } catch {
            Terminal.report(error)
            exit(1)
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
        print("\nType a number or a name, and any arguments, such as \(Style.bold("catalog vision")). Return quits.")
    }

    static func showHelp() {
        print("Usage: showcase <command> [arguments]\n")
        for command in commands {
            print("  " + "\(command.name) \(command.usage)".padded(to: 32) + command.summary)
        }
        print("\nWithout a command, showcase shows a menu. Every command but catalog needs OPENROUTER_API_KEY.")
    }

    static let missingKey = """
        This command calls OpenRouter, so it needs an API key. Create one at https://openrouter.ai/keys, then:

          In a terminal:  export OPENROUTER_API_KEY=<your key>
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

/// Returns the OpenRouter API key from the environment, for each request a model sends.
///
/// The environment suits development only. An app never ships a key, where anyone can extract it: it lets people
/// enter their own, or sends requests through its own server.
func openRouterKey() -> String {
    ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? ""
}
