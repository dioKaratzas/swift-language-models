import Foundation
import FoundationModels
import OpenRouterLanguageModels

/// A chat that streams each answer as it arrives, with a footer of what the turn used and cost.
///
/// Any model in the catalog can answer, picked by its id. `/model` switches models mid-chat: a new session continues
/// the old one's transcript. `/effort` sets how much the model reasons, as each request's
/// `ContextOptions.ReasoningLevel`.
struct Chat: Command {
    let name = "chat"
    let summary = "Chat with any model in the catalog, streaming each answer"
    let usage = "[model-id]"

    func run(_ arguments: [String]) async throws {
        let id = arguments.first ?? "anthropic/claude-haiku-5.5"
        guard var model = Self.model(id) else {
            throw UsageError("The catalog has no model \(id). `showcase catalog` lists them.")
        }
        var session = LanguageModelSession(model: model, instructions: "You're a friendly assistant. Keep answers short.")
        var context = ContextOptions()
        print(Style.dim("Chatting with \(model.details.displayName). Type /model <id>, /effort <level> or /quit."))

        while let line = Terminal.ask("\n› ") {
            let words = line.split(separator: " ").map(String.init)
            let argument = words.dropFirst().first ?? ""
            switch words.first {
            case "/quit":
                return
            case "/model":
                guard let picked = Self.model(argument) else {
                    Terminal.printError("The catalog has no model \(argument).")
                    continue
                }
                model = picked
                session = LanguageModelSession(model: model, transcript: session.transcript)
                print(Style.dim("Chatting with \(model.details.displayName)."))
            case "/effort":
                let levels = model.details.reasoningEfforts
                guard let level = levels.first(where: { $0 == .custom(argument) }) else {
                    let names = levels.isEmpty ? "no levels" : levels.map(\.name).joined(separator: ", ")
                    print(Style.dim("\(model.details.displayName) takes \(names)."))
                    continue
                }
                context.reasoningLevel = level
                print(Style.dim("Reasoning at \(argument)."))
            case nil:
                continue
            default:
                await reply(to: line, in: session, context: context)
            }
        }
    }

    private func reply(to line: String, in session: LanguageModelSession, context: ContextOptions) async {
        do {
            let stream = session.streamResponse(to: line, contextOptions: context)
            var answer = Streamer()
            for try await snapshot in stream {
                answer.show(snapshot.content)
            }
            answer.finish()
            print(Footer(try await stream.collect()))
        } catch {
            Terminal.report(error)
        }
    }

    /// The catalog's model with the given id. Its efforts are in their open form, since the id is known only at
    /// runtime.
    private static func model(_ id: String) -> OpenRouterLanguageModel<ContextOptions.ReasoningLevel>? {
        OpenRouterModel(catalogID: OpenRouterModelID(rawValue: id)).map { OpenRouterLanguageModel($0, apiKey: openRouterKey) }
    }
}

extension ContextOptions.ReasoningLevel {
    /// The level's name, such as `high`.
    fileprivate var name: String {
        if case .custom(let name) = self { name } else { "\(self)" }
    }
}
