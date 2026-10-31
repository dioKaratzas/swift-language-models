import Foundation
import FoundationModels
import OpenRouterLanguageModels

/// Tool calling: the model asks for forecasts and conversions, Foundation Models runs the tools, and the model answers
/// from their output.
///
/// A model can ask for several calls in one round, such as a forecast for each city, and the session's transcript
/// keeps each round as one entry. A tool is plain Foundation Models code, and works with any model that calls tools,
/// as here with Gemini.
struct Tools: Command {
    let name = "tools"
    let summary = "Let the model call two tools, several calls a round, printing each call"
    let usage = "[question]"

    func run(_ arguments: [String]) async throws {
        let model = OpenRouterLanguageModel(.googleGemini2_5FlashLite, auth: .apiKey(openRouterKey))
        let session = LanguageModelSession(model: model, tools: [Forecast(), ConvertTemperature()])
        let question = arguments.text(
            or: "Do I need an umbrella in Lisbon or in Porto tomorrow? Give the temperatures in Fahrenheit too.")

        var answer = Streamer()
        for try await snapshot in session.streamResponse(to: question) {
            answer.show(snapshot.content)
        }
        answer.finish()

        var round = 0
        for case .toolCalls(let calls) in session.transcript {
            round += 1
            let called = calls.map { "\($0.toolName)\($0.arguments.jsonString)" }.joined(separator: ", ")
            let together = calls.count > 1 ? ", asked for together" : ""
            print(Style.dim("Round \(round): \(called)\(together)"))
        }
    }

    /// Made-up forecasts, which the model can't know without calling the tool.
    struct Forecast: Tool {
        let name = "getForecast"
        let description = "Gets tomorrow's weather forecast for a city, in degrees Celsius."

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

    /// Converts a temperature, so the model has a second tool to combine with the first.
    struct ConvertTemperature: Tool {
        let name = "convertTemperature"
        let description = "Converts a temperature from degrees Celsius to degrees Fahrenheit."

        @Generable
        struct Arguments {
            @Guide(description: "The temperature in degrees Celsius.")
            var celsius: Double
        }

        func call(arguments: Arguments) async throws -> String {
            let fahrenheit = (arguments.celsius * 9 / 5 + 32).formatted(
                .number.precision(.fractionLength(0...1)).locale(Locale(identifier: "en_US_POSIX")))
            print(Style.cyan("\(name)(celsius: \(arguments.celsius)) → \(fahrenheit) °F"))
            return "\(fahrenheit) °F"
        }
    }
}
