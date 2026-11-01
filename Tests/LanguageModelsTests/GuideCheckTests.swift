import FoundationModels
import LanguageModels
import Testing

@Suite("Guide check")
struct GuideCheckTests {
    @Test func `an answer that breaks a guide throws the parsing error, naming the value and the guide`() async throws {
        let session = LanguageModelSession(model: FixedAnswerModel(answer: #"{"minutes":2,"steps":["Boil."]}"#))

        let error = await #expect(throws: GeneratedContent.ParsingError.self) {
            try await session.respond(to: "A quick dinner.", generating: Dinner.self)
        }

        #expect(error?.rawContent == #"{"minutes":2,"steps":["Boil."]}"#)
        #expect(
            error?.debugDescription
                == "The answer breaks its schema's guides: minutes is 2, below the minimum of 5; steps has 1 item, fewer than the minimum of 3."
        )
    }

    @Test func `an answer that meets its guides decodes`() async throws {
        let session = LanguageModelSession(model: FixedAnswerModel(answer: #"{"minutes":20,"steps":["Chop.","Fry.","Serve."]}"#))

        let dinner = try await session.respond(to: "A quick dinner.", generating: Dinner.self).content

        #expect(dinner.minutes == 20)
    }

    @Test func `an enum's case is checked against the case it names`() async throws {
        let session = LanguageModelSession(model: FixedAnswerModel(answer: #"{"shape":{"type":"circle","value":{"radius":0}}}"#))

        let error = await #expect(throws: GeneratedContent.ParsingError.self) {
            try await session.respond(to: "A shape.", generating: Drawing.self)
        }

        #expect(error?.debugDescription == "The answer breaks its schema's guides: shape.value.radius is 0, below the minimum of 1.")
    }

    @Test func `an answer that isn't JSON is left to the decoding`() async throws {
        let session = LanguageModelSession(model: FixedAnswerModel(answer: "Twenty minutes."))

        let error = await #expect(throws: GeneratedContent.ParsingError.self) {
            try await session.respond(to: "A quick dinner.", generating: Dinner.self)
        }

        #expect(error?.debugDescription.hasPrefix("The answer breaks") == false)
    }

    @Test func `an answer without a schema isn't checked`() async throws {
        let session = LanguageModelSession(model: FixedAnswerModel(answer: #"{"minutes":2}"#))

        #expect(try await session.respond(to: "A quick dinner.").content == #"{"minutes":2}"#)
    }
}

@Generable
private struct Circle {
    @Guide(.minimum(1))
    var radius: Int
}

@Generable
private enum Shape {
    case circle(Circle)
    case square(side: Int)
}

@Generable
private struct Drawing {
    var shape: Shape
}

@Generable
private struct Dinner {
    @Guide(.range(5...120))
    var minutes: Int

    @Guide(.count(3))
    var steps: [String]
}
