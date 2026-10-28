import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

/// The catalog's router models.
private typealias Routers = OpenRouterModel<Efforts.Unsupported>

/// The plugin that every request sends first.
private let contextCompression: JSONValue = ["id": "context-compression", "enabled": false]

/// Auto Router settings with every field set.
private let autoRouter = OpenRouterAutoRouter(
    allowedModels: ["anthropic/*", "openai/gpt-5*"], excludedModels: ["openai/gpt-4o"], costTier: .medium)

@Suite("Executor: routing")
struct ExecutorRoutingTests {
    @Test func `routing preferences go in the provider object, with prices as exact decimal strings`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let routing = OpenRouterRouting(
            requiresDistillableText: true,
            sort: .throughput,
            sortPartition: .acrossModels,
            maximumPrice: .init(
                prompt: Decimal(string: "0.15"), completion: 2, image: Decimal(string: "0.04"), audio: Decimal(string: "0.001"),
                request: Decimal(string: "0.005")),
            preferredMinimumThroughput: .init(p50: 100, p90: 50),
            preferredMaximumLatency: .init(p50: .seconds(1), p90: .milliseconds(2_500))
        )

        _ = try await LanguageModelSession(model: model(stub, routing: routing)).respond(to: "Hi")

        let request = try #require(stub.requests.first)
        let provider =
            #""provider":{"enforce_distillable_text":true,"sort":{"by":"throughput","partition":"none"},"#
            + #""max_price":{"prompt":"0.15","completion":"2","image":"0.04","audio":"0.001","request":"0.005"},"#
            + #""preferred_min_throughput":{"p50":100,"p90":50},"preferred_max_latency":{"p50":1,"p90":2.5}}"#
        #expect(String(decoding: request.body, as: UTF8.self).contains(provider))
    }

    @Test(arguments: [
        (OpenRouterRouting.Percentiles<Double>(p50: 100), JSONValue.integer(100)),
        (.init(p50: 100, p90: 50), .object(["p50": 100, "p90": 50])),
        (.init(p99: 20.5), .object(["p99": 20.5])),
    ])
    func `a throughput threshold on the median alone is one number, and any other is an object`(
        threshold: OpenRouterRouting.Percentiles<Double>,
        json: JSONValue
    ) async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let routing = OpenRouterRouting(preferredMinimumThroughput: threshold)

        _ = try await LanguageModelSession(model: model(stub, routing: routing)).respond(to: "Hi")

        #expect(try body(stub)["provider"] == ["preferred_min_throughput": json])
    }

    @Test(arguments: [
        (OpenRouterRouting.Percentiles<Duration>(p50: .seconds(2)), JSONValue.integer(2)),
        (
            .init(p50: .seconds(1), p75: .milliseconds(1_500), p90: .seconds(3), p99: .seconds(10)),
            .object(["p50": 1, "p75": 1.5, "p90": 3, "p99": 10])
        ),
    ])
    func `a latency threshold is sent in seconds, as one number for the median alone`(
        threshold: OpenRouterRouting.Percentiles<Duration>,
        json: JSONValue
    ) async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let routing = OpenRouterRouting(preferredMaximumLatency: threshold)

        _ = try await LanguageModelSession(model: model(stub, routing: routing)).respond(to: "Hi")

        #expect(try body(stub)["provider"] == ["preferred_max_latency": json])
    }

    @Test func `thresholds and price limits with nothing set are left out`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let routing = OpenRouterRouting(maximumPrice: .init(), preferredMinimumThroughput: .init(), preferredMaximumLatency: .init())

        _ = try await LanguageModelSession(model: model(stub, routing: routing)).respond(to: "Hi")

        #expect(try body(stub)["provider"] == nil)
    }

    @Test(arguments: [
        (OpenRouterRouting(sort: .latency), JSONValue.string("latency")),
        (OpenRouterRouting(sort: .price, sortPartition: .acrossModels), .object(["by": "price", "partition": "none"])),
        (OpenRouterRouting(sortPartition: .byModel), .object(["partition": "model"])),
    ])
    func `a sort is its name alone, or an object once it has a partition`(routing: OpenRouterRouting, sort: JSONValue) async throws {
        let stub = HTTPStub(events(text("Hi"), done()))

        _ = try await LanguageModelSession(model: model(stub, routing: routing)).respond(to: "Hi")

        #expect(try body(stub)["provider"] == ["sort": sort])
    }

    @Test(arguments: [
        (OpenRouterModelID("vendor/model"), OpenRouterRouting.Variant.nitro, "vendor/model:nitro"),
        (OpenRouterModelID("vendor/model"), .floor, "vendor/model:floor"),
        (OpenRouterModelID("vendor/model:free"), .nitro, "vendor/model:free:nitro"),
        (OpenRouterModelID("vendor/model"), "exacto", "vendor/model:exacto"),
    ])
    func `a variant, even one without a static member, suffixes the model id the request names, while the details keep the catalog id`(
        id: OpenRouterModelID,
        variant: OpenRouterRouting.Variant,
        requested: String
    ) async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let model = model(stub, id: id, routing: OpenRouterRouting(variant: variant))

        _ = try await LanguageModelSession(model: model).respond(to: "Hi")

        let body = try body(stub)
        #expect(body["model"] == .string(requested))
        #expect(body["provider"] == nil)
        #expect(model.details.id == id)
    }

    @Test func `a variant with a sort sends both, so the sort ranks the hosts`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let routing = OpenRouterRouting(sort: .latency, variant: .nitro)

        _ = try await LanguageModelSession(model: model(stub, routing: routing)).respond(to: "Hi")

        let body = try body(stub)
        #expect(body["model"] == "vendor/model:nitro")
        #expect(body["provider"] == ["sort": "latency"])
    }

    @Test(arguments: [
        (Routers.openrouterAuto.id, "auto-router"),
        (Routers.openrouterAutoBeta.id, "auto-beta-router"),
    ])
    func `an auto router gets its settings under its own plugin id, after context compression`(
        id: OpenRouterModelID,
        pluginID: String
    ) async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let options = OpenRouterOptions(autoRouter: autoRouter, minimumCodingScore: 0.8)

        _ = try await LanguageModelSession(model: model(stub, id: id, options: options)).respond(to: "Hi")

        let request = try #require(stub.requests.first)
        let plugins =
            #""plugins":[{"id":"context-compression","enabled":false},{"id":"\#(pluginID)","#
            + #""allowed_models":["anthropic/*","openai/gpt-5*"],"excluded_models":["openai/gpt-4o"],"cost_tier":"medium"}]"#
        #expect(String(decoding: request.body, as: UTF8.self).contains(plugins))
    }

    @Test func `the Pareto router gets its minimum coding score, after context compression`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let options = OpenRouterOptions(autoRouter: autoRouter, minimumCodingScore: 0.8)

        _ = try await LanguageModelSession(model: model(stub, id: Routers.openrouterParetoCode.id, options: options)).respond(to: "Hi")

        #expect(try body(stub)["plugins"] == [contextCompression, ["id": "pareto-router", "min_coding_score": 0.8]])
    }

    @Test(arguments: [
        (Routers.openrouterAuto.id, OpenRouterOptions(minimumCodingScore: 0.8)),
        (Routers.openrouterAutoBeta.id, OpenRouterOptions()),
        (Routers.openrouterParetoCode.id, OpenRouterOptions(autoRouter: autoRouter)),
        (OpenRouterModelID("vendor/model"), OpenRouterOptions(autoRouter: autoRouter, minimumCodingScore: 0.8)),
        (Routers.openrouterFree.id, OpenRouterOptions(autoRouter: autoRouter, minimumCodingScore: 0.8)),
    ])
    func `a model gets context compression alone when no router setting is its own`(id: OpenRouterModelID, options: OpenRouterOptions)
        async throws
    {
        let stub = HTTPStub(events(text("Hi"), done()))

        _ = try await LanguageModelSession(model: model(stub, id: id, options: options)).respond(to: "Hi")

        #expect(try body(stub)["plugins"] == [contextCompression])
    }
}
