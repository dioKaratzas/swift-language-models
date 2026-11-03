import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenAILanguageModels

/// Exchanges whose every byte and answer is pinned, so a change to how requests are built or answers are read shows
/// up here: the request bodies, OpenAI's headers, the session's transcript, the usage, a streamed answer's last
/// snapshot, and the error it ends in.
@Suite("Executor: exact exchanges")
struct ExecutorExactExchangeTests {
    @Test func `the exact requests and answer of a streamed answer with reasoning and OpenAI's options`() async {
        let exchange = await ExactExchange.textWithOptions()

        #expect(
            exchange.bodies == [
                #"{"model":"gpt-test","input":[{"role":"developer","content":"Be brief."},{"role":"user","content":"Plan the week."}],"stream":true,"store":false,"include":["reasoning.encrypted_content"],"text":{"verbosity":"low"},"reasoning":{"effort":"low","summary":"auto"},"max_output_tokens":100,"metadata":{"team":"coach"},"service_tier":"flex","prompt_cache_key":"<generated id>","safety_identifier":"user-1"}"#
            ])
        #expect(exchange.headers == [["OpenAI-Organization: org-1", "OpenAI-Project: proj-1"]])
        #expect(
            exchange.transcript == [
                #"instructions ["Be brief."] tools: []"#,
                #"prompt ["Plan the week."] metadata: {"team":"coach"}"#,
                #"reasoning ["Plan it."] metadata: {"model":"gpt-test-2026-10-01","reasoningOrigin":"openai-responses"} signature: "[{\"encrypted_content\":\"blob-1\",\"id\":\"rs_1\",\"summary\":[{\"text\":\"Plan it.\",\"type\":\"summary_text\"}],\"type\":\"reasoning\"}]""#,
                #"response ["Start Monday."] metadata: {"finishReason":"stop","model":"gpt-test-2026-10-01","openAI.phases":[{"length":13,"phase":"final_answer"}],"requestID":"req_1","responseID":"resp_1","serviceTier":"default"}"#,
            ])
        #expect(exchange.usage == #"input 12 cached 4, output 9 reasoning 3, metadata: {}"#)
        #expect(
            exchange.lastSnapshot
                == #""Start Monday." ["reasoning [\"Plan it.\"] metadata: {\"model\":\"gpt-test-2026-10-01\",\"reasoningOrigin\":\"openai-responses\"} signature: \"[{\\\"encrypted_content\\\":\\\"blob-1\\\",\\\"id\\\":\\\"rs_1\\\",\\\"summary\\\":[{\\\"text\\\":\\\"Plan it.\\\",\\\"type\\\":\\\"summary_text\\\"}],\\\"type\\\":\\\"reasoning\\\"}]\"", "response [\"Start Monday.\"] metadata: {\"finishReason\":\"stop\",\"model\":\"gpt-test-2026-10-01\",\"openAI.phases\":[{\"length\":13,\"phase\":\"final_answer\"}],\"requestID\":\"req_1\",\"responseID\":\"resp_1\",\"serviceTier\":\"default\"}"]"#
        )
        #expect(exchange.error == nil)
    }

    @Test
    func `the exact requests and answer of parallel tool calls whose reasoning goes back before them, and the answer to their outputs`()
        async
    {
        let exchange = await ExactExchange.toolRound()

        #expect(
            exchange.bodies == [
                #"{"model":"gpt-test","input":[{"role":"user","content":"Calories in an egg and rice?"}],"stream":true,"include":["reasoning.encrypted_content"],"tools":[{"type":"function","name":"lookUpFood","description":"Looks up a food's calories.","parameters":{"additionalProperties":false,"properties":{"food":{"type":"string"}},"required":["food"],"title":"Arguments","type":"object"},"strict":false}],"parallel_tool_calls":true}"#,
                #"{"model":"gpt-test","input":[{"role":"user","content":"Calories in an egg and rice?"},{"encrypted_content":"blob-1","id":"rs_1","summary":[{"text":"Look both up.","type":"summary_text"}],"type":"reasoning"},{"type":"function_call","call_id":"call_1","name":"lookUpFood","arguments":"{\"food\":\"egg\"}"},{"type":"function_call","call_id":"call_2","name":"lookUpFood","arguments":"{\"food\":\"rice\"}"},{"type":"function_call_output","call_id":"call_1","output":"egg: 100 kcal"},{"type":"function_call_output","call_id":"call_2","output":"rice: 100 kcal"}],"stream":true,"include":["reasoning.encrypted_content"],"tools":[{"type":"function","name":"lookUpFood","description":"Looks up a food's calories.","parameters":{"additionalProperties":false,"properties":{"food":{"type":"string"}},"required":["food"],"title":"Arguments","type":"object"},"strict":false}],"parallel_tool_calls":true}"#,
            ])
        #expect(exchange.headers == [[], []])
        #expect(
            exchange.transcript == [
                #"instructions [] tools: ["lookUpFood"]"#,
                #"prompt ["Calories in an egg and rice?"] metadata: {}"#,
                #"reasoning ["Look both up."] metadata: {"model":"gpt-test-2026-10-01","reasoningOrigin":"openai-responses"} signature: "[{\"encrypted_content\":\"blob-1\",\"id\":\"rs_1\",\"summary\":[{\"text\":\"Look both up.\",\"type\":\"summary_text\"}],\"type\":\"reasoning\"}]""#,
                #"toolCalls ["call_1 lookUpFood {\"food\":\"egg\"} metadata: {\"finishReason\":\"tool_calls\",\"model\":\"gpt-test-2026-10-01\",\"responseID\":\"resp_1\",\"serviceTier\":\"default\"}", "call_2 lookUpFood {\"food\":\"rice\"} metadata: {}"]"#,
                #"toolOutput call_1 lookUpFood ["egg: 100 kcal"]"#,
                #"toolOutput call_2 lookUpFood ["rice: 100 kcal"]"#,
                #"response ["Both have 100 kcal."] metadata: {"finishReason":"stop","model":"gpt-test-2026-10-01","responseID":"resp_1","serviceTier":"default"}"#,
            ])
        #expect(exchange.usage == #"input 40 cached 12, output 6 reasoning 0, metadata: {}"#)
        #expect(exchange.lastSnapshot == nil)
        #expect(exchange.error == nil)
    }

    @Test func `the exact requests and answer of a model that doesn't reason`() async {
        let exchange = await ExactExchange.plain()

        #expect(
            exchange.bodies == [
                #"{"model":"gpt-plain","input":[{"role":"system","content":"Be brief."},{"role":"user","content":"Hi"}],"stream":true,"temperature":0.5,"top_p":0.9}"#
            ])
        #expect(exchange.headers == [[]])
        #expect(
            exchange.transcript == [
                #"instructions ["Be brief."] tools: []"#,
                #"prompt ["Hi"] metadata: {}"#,
                #"response ["Hello."] metadata: {"finishReason":"stop","model":"gpt-plain","responseID":"resp_1","serviceTier":"default"}"#,
            ])
        #expect(exchange.usage == #"input 12 cached 0, output 5 reasoning 0, metadata: {}"#)
        #expect(exchange.lastSnapshot == nil)
        #expect(exchange.error == nil)
    }

    @Test func `the exact requests and answer of a streamed answer that an error event ends`() async {
        let exchange = await ExactExchange.errorMidStream()

        #expect(
            exchange.bodies == [
                #"{"model":"gpt-test","input":[{"role":"user","content":"Plan the week."}],"stream":true,"include":["reasoning.encrypted_content"]}"#
            ])
        #expect(exchange.headers == [[]])
        #expect(exchange.transcript.isEmpty)
        #expect(exchange.usage == nil)
        #expect(exchange.lastSnapshot == nil)
        #expect(
            exchange.error
                == #"OpenAIError(status: nil, message: "The server had an error.", code: server_error, parameter: nil, requestID: Optional("req_9"), retryAfter: nil, isQuotaExhausted: false)"#
        )
    }

    #if canImport(FoundationModels, _version: 2.1.14)
    @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
    @Test func `the exact requests and answer of an earlier prompt with an image and a PDF`() async throws {
        let exchange = try await ExactExchange.attachments()

        #expect(
            exchange.bodies == [
                #"{"model":"gpt-test","input":[{"role":"user","content":[{"type":"input_text","text":"Keep these."},{"type":"input_text","text":"Photo"},{"type":"input_image","image_url":"data:image/jpeg;base64,<jpeg>","detail":"auto"},{"type":"input_text","text":"Menu"},{"type":"input_file","filename":"Menu.pdf","file_data":"data:application/pdf;base64,JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCA2MTIgNzkyXSAvQ29udGVudHMgNCAwIFIgL1Jlc291cmNlcyA8PCAvRm9udCA8PCAvRjEgNSAwIFIgPj4gPj4gPj4KZW5kb2JqCjQgMCBvYmoKPDwgL0xlbmd0aCA0NiA+PgpzdHJlYW0KQlQgL0YxIDI0IFRmIDcyIDcyMCBUZCAoU291cCBvZiB0aGUgZGF5KSBUaiBFVAplbmRzdHJlYW0KZW5kb2JqCjUgMCBvYmoKPDwgL1R5cGUgL0ZvbnQgL1N1YnR5cGUgL1R5cGUxIC9CYXNlRm9udCAvSGVsdmV0aWNhID4+CmVuZG9iagp4cmVmCjAgNgowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwMDkgMDAwMDAgbiAKMDAwMDAwMDA1OCAwMDAwMCBuIAowMDAwMDAwMTE1IDAwMDAwIG4gCjAwMDAwMDAyNDEgMDAwMDAgbiAKMDAwMDAwMDMzNyAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDYgL1Jvb3QgMSAwIFIgPj4Kc3RhcnR4cmVmCjQwNwolJUVPRgo="}]},{"role":"assistant","content":"Kept."},{"role":"user","content":"What's in these?"}],"stream":true,"include":["reasoning.encrypted_content"]}"#
            ])
        #expect(exchange.headers == [[]])
        #expect(
            exchange.transcript == [
                #"prompt ["Keep these.", attachment Photo, attachment Menu] metadata: {}"#,
                #"response ["Kept."] metadata: {"assetIDs":[]}"#,
                #"prompt ["What's in these?"] metadata: {}"#,
                #"response ["A menu and a photo."] metadata: {"finishReason":"stop","model":"gpt-test-2026-10-01","responseID":"resp_1","serviceTier":"default"}"#,
            ])
        #expect(exchange.usage == #"input 12 cached 0, output 5 reasoning 0, metadata: {}"#)
        #expect(exchange.lastSnapshot == nil)
        #expect(exchange.error == nil)
    }
    #endif

    @Test func `a real streamed answer with reasoning ends in its text, its reasoning item, phase and usage`() async throws {
        let recorded = try Bundle.module.fixture("reasoning-stream.sse")
        let stub = HTTPStub(StubResponse(status: 200, headers: ["Content-Type": "text/event-stream"], chunks: [recorded]))
        let session = LanguageModelSession(model: reasoningModel(stub))

        let response = try await session.respond(to: "What is 17 times 23? Reply with the number only.")

        #expect(response.content == "391")
        #expect(response.usage.input.totalTokenCount == 20)
        #expect(response.usage.output.totalTokenCount == 17)
        #expect(response.usage.output.reasoningTokenCount == 10)
        let reasoning = try #require(
            response.transcriptEntries.compactMap { entry in if case .reasoning(let reasoning) = entry { reasoning } else { nil } }.first)
        let items = try JSONValue(json: try #require(reasoning.signature))
        #expect(items[0]?["id"]?.stringValue?.hasPrefix("rs_") == true)
        #expect(items[0]?["encrypted_content"]?.stringValue?.isEmpty == false)
        let answer = try #require(
            response.transcriptEntries.compactMap { entry in if case .response(let answer) = entry { answer } else { nil } }.last)
        #expect(answer.metadata[OpenAIMetadataKey.phases].map(JSONValue.init)?[0]?["phase"] == "final_answer")
        #expect(answer.metadata[LanguageModelMetadataKey.model].map(JSONValue.init) == "gpt-6-luna")
    }
}
