import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import ResponsesAPI

@Suite("Responses executor")
struct ResponsesExecutorTests {
    @Test func `a request goes to responses with the provider's headers, and its answer streams back`() async throws {
        let stub = HTTPStub(events(textDelta("Hi"), lifecycle("response.completed")))

        let (answer, failure) = await respond(stub, to: [prompt(text("Hello"))])

        if let failure { Issue.record("The answer failed: \(failure)") }
        #expect(answer?.responseText == "Hi")
        let sent = try #require(stub.requests.first)
        #expect(sent.request.url?.path == "/responses")
        #expect(sent.request.value(forHTTPHeaderField: "X-Test") == "yes")
        #expect(
            String(decoding: sent.body, as: UTF8.self)
                == #"{"model":"vendor/model","input":[{"role":"user","content":"Hello"}],"stream":true}"#)
    }

    @Test func `a stream that ends before the response completes is cut off, even after a done`() async {
        let stub = HTTPStub(.eventStream(Data("data: \(textDelta("Hi").text)\n\ndata: [DONE]\n\n".utf8)))

        let (_, failure) = await respond(stub, to: [prompt(text("Hello"))])

        guard case .unusableResponse(.cutOff)? = failure?.kind else {
            Issue.record("The answer ended with \(String(describing: failure))")
            return
        }
    }

    @Test(
        arguments: [
            ["type": "error", "code": "server_error", "message": "Overloaded.", "param": nil, "sequence_number": 2],
            ["type": "error", "sequence_number": 2, "error": ["type": "server_error", "code": "server_error", "message": "Overloaded."]],
        ] as [JSONValue])
    func `an error event mid-stream fails the answer with its error, flat or nested`(event: JSONValue) async {
        let stub = HTTPStub(events(textDelta("Hi"), event))

        let (_, failure) = await respond(stub, to: [prompt(text("Hello"))])

        guard case .errorEvent(let error)? = failure?.kind else {
            Issue.record("The answer ended with \(String(describing: failure))")
            return
        }
        #expect(error.message == "Overloaded.")
        #expect(error.code == "server_error")
    }

    @Test func `a failed response fails the answer with the response's error`() async {
        let stub = HTTPStub(
            events(textDelta("Hi"), lifecycle("response.failed", ["error": ["code": "rate_limit_exceeded", "message": "Slow down."]])))

        let (_, failure) = await respond(stub, to: [prompt(text("Hello"))])

        guard case .failedResponse(let error)? = failure?.kind else {
            Issue.record("The answer ended with \(String(describing: failure))")
            return
        }
        #expect(error?.message == "Slow down.")
        #expect(error?.code == "rate_limit_exceeded")
    }

    @Test func `a failed response's error object names what went wrong`() async {
        let stub = HTTPStub(
            .json(#"{"error":{"message":"Bad key.","type":"invalid_request_error","code":"invalid_api_key"}}"#, status: 401))

        let (_, failure) = await respond(stub, to: [prompt(text("Hello"))])

        guard case .rejected(let rejection)? = failure?.kind else {
            Issue.record("The answer ended with \(String(describing: failure))")
            return
        }
        #expect(rejection.status == 401)
        #expect(rejection.body?.message == "Bad key.")
    }

    @Test func `a host that rejects a constraint of the schema gets the portable schema once`() async throws {
        let rejection = #"{"error":{"message":"Keyword 'maximum' is not supported for type 'integer'"}}"#
        let stub = HTTPStub(.json(rejection, status: 400), events(textDelta(#"{"stars":4}"#), lifecycle("response.completed")))

        let (answer, failure) = await respond(stub, to: [prompt(text("Rate it."))], schema: Rating.generationSchema)

        if let failure { Issue.record("The answer failed: \(failure)") }
        #expect(answer?.responseText == #"{"stars":4}"#)
        let bodies = try stub.requests.map { try JSONValue(json: $0.body) }
        #expect(bodies.count == 2)
        #expect(bodies.first?["text"]?["format"]?["schema"]?["properties"]?["stars"]?["maximum"] == 5)
        #expect(bodies.last?["text"]?["format"]?["schema"]?["properties"]?["stars"]?["maximum"] == nil)
    }

    @Test func `a refusal fails the answer as Foundation Models' refusal`() async {
        let refusal: JSONValue = ["type": "response.refusal.delta", "output_index": 0, "content_index": 0, "delta": "I can't."]
        let stub = HTTPStub(events(refusal, lifecycle("response.completed")))

        let (_, error) = await respondThrowing(stub, to: [prompt(text("Hello"))])

        guard case .refusal? = error as? LanguageModelError else {
            Issue.record("The answer ended with \(String(describing: error))")
            return
        }
    }

    @Test func `an answer a content filter stopped fails as a guardrail violation`() async {
        let stub = HTTPStub(events(textDelta("Hi"), lifecycle("response.incomplete", ["incomplete_details": ["reason": "content_filter"]])))

        let (_, error) = await respondThrowing(stub, to: [prompt(text("Hello"))])

        guard case .guardrailViolation? = error as? LanguageModelError else {
            Issue.record("The answer ended with \(String(describing: error))")
            return
        }
    }

    @Test func `an answer whose token limit cuts off a function call fails`() async {
        let stub = HTTPStub(
            events(
                item(
                    "response.output_item.added", at: 0, ["type": "function_call", "call_id": "call_1", "name": "lookUp", "arguments": ""]),
                ["type": "response.function_call_arguments.delta", "output_index": 0, "delta": #"{"word""#],
                lifecycle("response.incomplete", ["incomplete_details": ["reason": "max_output_tokens"]])))

        let (_, failure) = await respond(stub, to: [prompt(text("Hello"))])

        guard case .unusableResponse(.tokenLimitInToolCall)? = failure?.kind else {
            Issue.record("The answer ended with \(String(describing: failure))")
            return
        }
    }

    @Test func `a failed response without an error object fails the answer all the same`() async {
        let stub = HTTPStub(events(textDelta("Hi"), lifecycle("response.failed", ["status": "failed"])))

        let (_, failure) = await respond(stub, to: [prompt(text("Hello"))])

        guard case .failedResponse(nil)? = failure?.kind else {
            Issue.record("The answer ended with \(String(describing: failure))")
            return
        }
    }

    @Test func `an event of a kind the format doesn't read is passed over, whatever its shape`() async {
        let shell: JSONValue = ["type": "response.shell_call_output_content.delta", "output_index": 0, "delta": ["stdout": "ok"]]
        let stub = HTTPStub(events(shell, textDelta("Hi"), lifecycle("response.completed")))

        let (answer, failure) = await respond(stub, to: [prompt(text("Hello"))])

        if let failure { Issue.record("The answer failed: \(failure)") }
        #expect(answer?.responseText == "Hi")
    }

    @Test func `function call arguments without an output index go to the last call`() async {
        let stub = HTTPStub(
            events(
                item(
                    "response.output_item.added", at: 0, ["type": "function_call", "call_id": "call_1", "name": "lookUp", "arguments": ""]),
                ["type": "response.function_call_arguments.delta", "delta": #"{"word":"egg"}"#],
                [
                    "type": "response.output_item.done",
                    "item": ["type": "function_call", "call_id": "call_1", "name": "lookUp", "arguments": #"{"word":"egg"}"#],
                ],
                lifecycle("response.completed")))

        let (answer, failure) = await respond(stub, to: [prompt(text("Hello"))])

        if let failure { Issue.record("The answer failed: \(failure)") }
        #expect(answer?.responseText == "")
    }
}

@Suite("Responses stream")
struct ResponsesStreamTests {
    @Test func `reasoning summaries, the reasoning item, text, citations, usage and the finish reason end up in the transcript`() async {
        let reasoningItem: JSONValue = [
            "type": "reasoning", "id": "rs_1", "encrypted_content": "blob",
            "summary": [["type": "summary_text", "text": "Count."], ["type": "summary_text", "text": "Seven."]],
        ]
        let summary = { (index: Int, delta: String) -> JSONValue in
            ["type": "response.reasoning_summary_text.delta", "output_index": 0, "summary_index": .integer(index), "delta": .string(delta)]
        }
        let citation: JSONValue = [
            "type": "response.output_text.annotation.added", "output_index": 1, "content_index": 0, "annotation_index": 0,
            "annotation": ["type": "url_citation", "url": "https://example.com/week", "title": "Week", "start_index": 0, "end_index": 5],
        ]
        let usage: JSONValue = [
            "input_tokens": 12, "input_tokens_details": ["cached_tokens": 4, "cache_write_tokens": 2], "output_tokens": 9,
            "output_tokens_details": ["reasoning_tokens": 3], "total_tokens": 21,
        ]
        let stub = HTTPStub(
            events(
                lifecycle("response.created", ["id": "resp_1", "model": "vendor/model-2026-10-01", "service_tier": "default"]),
                item("response.output_item.added", at: 0, ["type": "reasoning", "id": "rs_1", "summary": []]),
                summary(0, "Count."), summary(1, "Seven."),
                item("response.output_item.done", at: 0, reasoningItem),
                item("response.output_item.added", at: 1, ["type": "message", "id": "msg_1", "role": "assistant", "content": []]),
                textDelta("Seven ", at: 1), textDelta("days.", at: 1), citation,
                item("response.output_item.done", at: 1, ["type": "message", "id": "msg_1", "phase": "final_answer"]),
                lifecycle("response.completed", ["id": "resp_1", "model": "vendor/model-2026-10-01", "usage": usage])))

        let exchange = await ExactExchange(stub, LanguageModelSession(model: model(stub)), recordingHeaders: /^X-/) { session, _ in
            try await session.respond(to: "How many days in a week?").usage
        }

        #expect(exchange.error == nil)
        #expect(
            exchange.transcript == [
                #"prompt ["How many days in a week?"] metadata: {}"#,
                #"reasoning ["Count.\n\nSeven."] metadata: {"model":"vendor/model-2026-10-01","reasoningOrigin":"test-responses"} signature: "[{\"encrypted_content\":\"blob\",\"id\":\"rs_1\",\"summary\":[{\"text\":\"Count.\",\"type\":\"summary_text\"},{\"text\":\"Seven.\",\"type\":\"summary_text\"}],\"type\":\"reasoning\"}]""#,
                #"response ["Seven days."] metadata: {"cacheWriteTokenCount":2,"citations":[{"endOffset":5,"excerpt":null,"startOffset":0,"title":"Week","url":"https://example.com/week"}],"finishReason":"stop","model":"vendor/model-2026-10-01","responseID":"resp_1","serviceTier":"default","test.phases":[{"length":11,"phase":"final_answer"}]}"#,
            ])
        #expect(exchange.usage == #"input 12 cached 4, output 9 reasoning 3, metadata: {"cacheWriteTokenCount":2}"#)
    }

    @Test func `parallel function calls form one round, with arguments that stream or arrive whole, and go back with their outputs`() async
    {
        let stub = HTTPStub(
            events(
                item(
                    "response.output_item.added", at: 0, ["type": "function_call", "call_id": "call_1", "name": "lookUp", "arguments": ""]),
                ["type": "response.function_call_arguments.delta", "output_index": 0, "delta": #"{"word""#],
                item(
                    "response.output_item.added", at: 1, ["type": "function_call", "call_id": "call_2", "name": "lookUp", "arguments": ""]),
                ["type": "response.function_call_arguments.delta", "output_index": 0, "delta": #":"egg"}"#],
                item(
                    "response.output_item.done", at: 0,
                    ["type": "function_call", "call_id": "call_1", "name": "lookUp", "arguments": #"{"word":"egg"}"#]),
                item(
                    "response.output_item.done", at: 1,
                    ["type": "function_call", "call_id": "call_2", "name": "lookUp", "arguments": #"{"word":"rice"}"#]),
                lifecycle("response.completed")),
            events(textDelta("Both found."), lifecycle("response.completed")))

        let exchange = await ExactExchange(
            stub, LanguageModelSession(model: model(stub), tools: [LookUpTool()]), recordingHeaders: /^X-/
        ) { session, _ in
            try await session.respond(to: "Define egg and rice.").usage
        }

        #expect(exchange.error == nil)
        #expect(
            exchange.transcript.dropFirst(2).first
                == #"toolCalls ["call_1 lookUp {\"word\":\"egg\"} metadata: {\"finishReason\":\"tool_calls\"}", "call_2 lookUp {\"word\":\"rice\"} metadata: {}"]"#
        )
        #expect(exchange.bodies.count == 2)
        #expect(
            exchange.bodies.last?.contains(
                #"{"type":"function_call","call_id":"call_1","name":"lookUp","arguments":"{\"word\":\"egg\"}"},{"type":"function_call","call_id":"call_2","name":"lookUp","arguments":"{\"word\":\"rice\"}"},{"type":"function_call_output","call_id":"call_1","output":"egg"},{"type":"function_call_output","call_id":"call_2","output":"rice"}"#
            ) == true)
    }

    @Test func `a commentary and a final answer keep their own phases, and reasoning text shows as reasoning`() async {
        let reasoningText: JSONValue = [
            "type": "response.reasoning_text.delta", "output_index": 0, "content_index": 0, "delta": "Think.",
        ]
        let stub = HTTPStub(
            events(
                item("response.output_item.added", at: 0, ["type": "reasoning", "id": "rs_1", "summary": []]), reasoningText,
                item("response.output_item.done", at: 0, ["type": "reasoning", "id": "rs_1", "summary": [], "encrypted_content": "blob"]),
                item("response.output_item.added", at: 1, ["type": "message", "id": "msg_1", "phase": "commentary"]),
                textDelta("Checking. ", at: 1),
                item("response.output_item.done", at: 1, ["type": "message", "id": "msg_1", "phase": "commentary"]),
                item("response.output_item.added", at: 2, ["type": "message", "id": "msg_2"]), textDelta("Seven.", at: 2),
                item("response.output_item.done", at: 2, ["type": "message", "id": "msg_2", "phase": "final_answer"]),
                lifecycle("response.completed")))

        let exchange = await ExactExchange(stub, LanguageModelSession(model: model(stub)), recordingHeaders: /^X-/) { session, _ in
            try await session.respond(to: "How many days in a week?").usage
        }

        #expect(exchange.error == nil)
        #expect(exchange.transcript[1].hasPrefix(#"reasoning ["Think."]"#))
        #expect(
            exchange.transcript.last
                == #"response ["Checking. Seven."] metadata: {"finishReason":"stop","test.phases":[{"length":10,"phase":"commentary"},{"length":6,"phase":"final_answer"}]}"#
        )
    }

    @Test func `an answer that reaches its token limit keeps its text, with length as its finish reason`() async {
        let stub = HTTPStub(
            events(textDelta("Seven"), lifecycle("response.incomplete", ["incomplete_details": ["reason": "max_output_tokens"]])))

        let exchange = await ExactExchange(stub, LanguageModelSession(model: model(stub)), recordingHeaders: /^X-/) { session, _ in
            try await session.respond(to: "How many days in a week?").usage
        }

        #expect(exchange.error == nil)
        #expect(exchange.transcript.last == #"response ["Seven"] metadata: {"finishReason":"length"}"#)
    }
}

/// The test model, sending to a stub.
private func model(_ stub: HTTPStub) -> TestModel {
    TestModel(setup: TestModel.Setup(url: stub.baseURL, session: stub.session))
}

/// Sends one request through the test model's request executor to a stub, reading the channel's events without looking
/// at them, since a channel waits for its reader.
///
/// - Returns: The answer, or the failure it ended in.
private func respond(
    _ stub: HTTPStub,
    to entries: [Transcript.Entry],
    schema: GenerationSchema? = nil
) async -> (DetailedLanguageModelAnswer?, ResponsesFailure<TestDialect>?) {
    let (answer, error) = await respondThrowing(stub, to: entries, schema: schema)
    guard let error else { return (answer, nil) }
    guard let failure = error as? ResponsesFailure<TestDialect> else {
        Issue.record("The executor threw \(error)")
        return (nil, nil)
    }
    return (nil, failure)
}

/// Sends one request through the test model's request executor to a stub.
///
/// - Returns: The answer, or the error it ended in.
private func respondThrowing(
    _ stub: HTTPStub,
    to entries: [Transcript.Entry],
    schema: GenerationSchema? = nil
) async -> (DetailedLanguageModelAnswer?, (any Error)?) {
    let executor = TestModel.RequestExecutor(configuration: .init())
    let channel = LanguageModelExecutorGenerationChannel()
    let reader = Task { for try await _ in channel {} }
    defer { reader.cancel() }
    do {
        return (try await executor.execute(generationRequest(entries, schema: schema), model: model(stub), streamingInto: channel), nil)
    } catch {
        return (nil, error)
    }
}
