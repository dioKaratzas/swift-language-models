package import FoundationModels
import Testing

// What every provider's live tests share: tools whose answers a model can't know, a plan with the schema features
// providers differ on, and readers of a session's transcript.

/// A tool whose answer the model can't know, so an answer with it shows the tool ran.
package struct WeatherTool: Tool {
    package init() {}

    package let name = "getWeather"
    package let description = "Gets the current temperature in a city, in degrees Celsius."

    @Generable
    package struct Arguments {
        @Guide(description: "The city's name.")
        package var city: String
    }

    package func call(arguments: Arguments) async throws -> String {
        "It is 17 degrees in \(arguments.city)."
    }
}

/// A plan with the schema features providers differ on: a nested type, an enum, an exact count, ranges and an
/// optional property.
@Generable
package struct Trip {
    @Guide(description: "The city to visit.")
    package var city: String

    package var season: Season

    @Guide(description: "Three things to do.", .count(3))
    package var activities: [Activity]

    @Guide(description: "How many days to stay.", .range(1...14))
    package var days: Int

    package var note: String?
}

@Generable
package enum Season {
    case spring, summer, autumn, winter
}

@Generable
package struct Activity {
    package var name: String

    @Guide(description: "How many hours it takes.", .range(1...12))
    package var hours: Int
}

extension Transcript {
    /// Every tool call in the transcript, in order.
    package var toolCalls: [Transcript.ToolCall] {
        flatMap { entry -> [Transcript.ToolCall] in
            if case .toolCalls(let calls) = entry { Array(calls) } else { [] }
        }
    }

    /// The cities of every weather tool call in the transcript, in order.
    package func weatherCities() throws -> [String] {
        try toolCalls.filter { $0.toolName == "getWeather" }.map { try $0.arguments.value(String.self, forProperty: "city") }
    }
}

/// The last answer among the entries.
package func lastAnswer(in entries: some Sequence<Transcript.Entry>) -> Transcript.Response? {
    entries.compactMap { entry in if case .response(let answer) = entry { answer } else { nil } }.last
}

/// The reasoning entries among the entries, in order.
package func reasoningEntries(in entries: some Sequence<Transcript.Entry>) -> [Transcript.Reasoning] {
    entries.compactMap { entry in if case .reasoning(let reasoning) = entry { reasoning } else { nil } }
}

/// Attaches a value to the test's results, for reading what a provider returned.
package func record(_ value: Any, named name: String) {
    Attachment.record(String(describing: value), named: name)
}

/// A weather tool that ends the answer with ``ToolCallInterruption`` when it's called, so a test sees the first call
/// and no more.
package struct InterruptingWeatherTool: Tool {
    package init() {}

    package let name = "getWeather"
    package let description = "Gets the current temperature in a city, in degrees Celsius."

    @Generable
    package struct Arguments {
        @Guide(description: "The city's name.")
        package var city: String
    }

    package func call(arguments: Arguments) async throws -> String {
        throw ToolCallInterruption()
    }
}

/// The error that ``InterruptingWeatherTool`` throws.
package struct ToolCallInterruption: Error {
    package init() {}
}

/// Sends a prompt and stops at the first call of an ``InterruptingWeatherTool``, since a required tool choice stays on
/// for every round, and a model that honors it never stops calling tools.
///
/// The session keeps the transcript of the answer that the tool ended, so a test can read the call; by default a
/// failed answer is reverted.
///
/// - Returns: The response, or `nil` when the model called the tool.
package func respondUntilToolCall(
    _ session: LanguageModelSession,
    to prompt: String,
    options: GenerationOptions
) async throws -> LanguageModelSession.Response<String>? {
    session.transcriptErrorHandlingPolicy = .preserveTranscript
    do {
        return try await session.respond(to: prompt, options: options)
    } catch let error as LanguageModelSession.ToolCallError where error.underlyingError is ToolCallInterruption {
        return nil
    }
}
