import Foundation
import FoundationModels
import OpenRouterLanguageModels

/// Tool calling: the model asks for a forecast, Foundation Models runs the tool, and the model answers from its
/// output.
///
/// A tool is plain Foundation Models code, and works with any model that calls tools, as here with Gemini.
struct Tools: Command {
    let name = "tools"
    let summary = "Let the model call a weather tool, printing each call"
    let usage = "[question]"

    func run(_ arguments: [String]) async throws {
        let model = OpenRouterLanguageModel(.googleGemini2_5FlashLite, apiKey: openRouterKey)
        let session = LanguageModelSession(model: model, tools: [Forecast()])
        let question = arguments.text(or: "Do I need an umbrella in Lisbon or in Porto tomorrow?")

        var answer = Streamer()
        for try await snapshot in session.streamResponse(to: question) {
            answer.show(snapshot.content)
        }
        answer.finish()
    }

    /// Made-up forecasts, which the model can't know without calling the tool.
    struct Forecast: Tool {
        let name = "getForecast"
        let description = "Gets tomorrow's weather forecast for a city."

        @Generable
        struct Arguments {
            @Guide(description: "The city's name, such as Lisbon.")
            var city: String
        }

        func call(arguments: Arguments) async throws -> String {
            let forecast = arguments.city.count.isMultiple(of: 2) ? "Rain, 14 °C" : "Sunny, 22 °C"
            print(Style.cyan("\(name)(city: \(arguments.city)) → \(forecast)"))
            return forecast
        }
    }
}
