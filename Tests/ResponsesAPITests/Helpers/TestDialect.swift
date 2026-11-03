import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import UniformTypeIdentifiers

@testable import ResponsesAPI

/// A dialect that adds only what a test gives it, and sends the format's reasoning items back, so the format's own
/// behavior shows.
///
/// Its errors are the format's failures themselves, so a test can read what failed.
struct TestDialect: ResponsesDialect {
    typealias Model = TestModel
    typealias ProviderError = ResponsesFailure<TestDialect>
    typealias BodyExtras = JSONValue
    typealias ReplayMembers = ReasoningItem
    typealias EventExtras = TestExtras
    typealias StreamState = TestStreamState

    let setup: TestModel.Setup

    init(model: TestModel, executor: TestModel.RequestExecutor) {
        setup = model.setup
    }

    init(_ setup: TestModel.Setup = TestModel.Setup()) {
        self.setup = setup
    }

    static var name: String { "Test" }

    /// The tier the test adds goes after the model, as a provider may order its members.
    static var memberOrder: [MemberKey] { [.model, "service_tier", .input] }

    /// The members a test may leave out.
    static var listedMembers: Set<MemberKey> { [.temperature, .maxOutputTokens, .topP] }

    var modelID: TestModelID { "vendor/model" }

    var baseURL: URL { setup.url }

    var connection: ProviderConnection {
        ProviderConnection(
            session: setup.session, authentication: RequestAuthentication(baseURL: nil) { [:] }, idleTimeout: nil, retryDelay: .zero)
    }

    var instructionsRole: InstructionsRole { setup.instructionsRole }

    func headers(_ context: HeaderContext) -> [HTTPHeaderName: String] { ["X-Test": "yes"] }

    func lists(_ member: MemberKey) -> Bool { setup.lists(member) }

    func body(_ context: BodyContext) throws(LanguageModelError) -> BodyPlan<JSONValue> {
        try setup.plan(context)
    }

    func streamState(_ headers: ResponseHeaders) -> TestStreamState { TestStreamState() }

    func observe(_ extras: TestExtras, into state: inout TestStreamState) -> EventOutput {
        state.host = extras.host ?? state.host
        return EventOutput()
    }

    func facts(of state: TestStreamState) -> AnswerFacts {
        var metadata: [String: any ConvertibleToGeneratedContent] = [:]
        metadata[LanguageModelMetadataKey.provider] = state.host
        return AnswerFacts(host: state.host, metadata: metadata)
    }

    func error(for failure: ResponsesFailure<TestDialect>) -> MappedError<ResponsesFailure<TestDialect>> {
        .provider(failure)
    }
}

/// The host the events named.
struct TestStreamState: Sendable {
    var host: String?
}

/// The members of an event only the test dialect reads: the host.
struct TestExtras: Decodable {
    let host: String?
}

/// The id of the test model.
struct TestModelID: ProviderVocabulary {
    let rawValue: String
}

/// A model whose requests go through the test dialect.
struct TestModel: DetailedLanguageModel {
    /// What the test dialect adds to a request, and where it goes.
    struct Setup: Sendable {
        /// The provider's base URL, such as a stub's.
        var url = URL(fileURLWithPath: "/")

        /// The session that sends the requests.
        var session = URLSession.shared

        /// The dialect's plan for a request's body.
        var plan: @Sendable (BodyContext) throws(LanguageModelError) -> BodyPlan<JSONValue> = { _ in BodyPlan(extras: [:]) }

        /// Whether the models list a member that goes out only when they do.
        var lists: @Sendable (MemberKey) -> Bool = { _ in true }

        /// The role of the instructions' messages.
        var instructionsRole = InstructionsRole.developer
    }

    struct Details: ModelDetails {
        let id: TestModelID = "vendor/model"
        let displayName = "Model"
        let capabilities = LanguageModelCapabilities([.guidedGeneration, .toolCalling, .reasoning])
        let reasoning = ModelReasoning.onByDefault
        let contextSize: Int? = 1_000
        let reasoningEfforts: [Efforts.Unsupported] = []
        let defaultReasoningEffort: Efforts.Unsupported? = nil
        let removalDate: Date? = nil
        let dataAttachmentTypes: Set<UTType> = [.image, .pdf]
        let dataEntryTypes: Set<UTType> = []
    }

    struct RequestExecutor: DetailedLanguageModelRequestExecutor {
        struct Configuration: Hashable, Sendable {}

        init(configuration: Configuration) {}

        func execute(
            _ request: LanguageModelExecutorGenerationRequest,
            model: TestModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws -> DetailedLanguageModelAnswer {
            try await respond(to: request, model: model, streamingInto: channel, as: TestDialect.self)
        }
    }

    var setup = Setup()
    let details = Details()
    let fallbacks: [Details] = []

    var executorConfiguration: RequestExecutor.Configuration { .init() }
}

/// What Foundation Models asks the executor for.
func generationRequest(
    _ entries: [Transcript.Entry],
    tools: [Transcript.ToolDefinition] = [],
    schema: GenerationSchema? = nil,
    options: GenerationOptions = GenerationOptions(),
    metadata: [String: any ConvertibleToGeneratedContent] = [:]
) -> LanguageModelExecutorGenerationRequest {
    LanguageModelExecutorGenerationRequest(
        id: UUID(), transcript: Transcript(entries: entries), enabledTools: tools, schema: schema, generationOptions: options,
        contextOptions: ContextOptions(), metadata: metadata)
}

/// A prompt entry with the given segments.
func prompt(_ segments: Transcript.Segment...) -> Transcript.Entry {
    .prompt(Transcript.Prompt(segments: segments))
}

/// A text segment.
func text(_ content: String) -> Transcript.Segment {
    .text(.init(content: content))
}

/// The input items of a request body.
func input(_ body: JSONValue) -> [JSONValue] {
    if case .array(let items)? = body["input"] { items } else { [] }
}

/// The keys of an object, in order.
func keys(_ value: JSONValue?) -> [String] {
    if case .object(let object)? = value { object.members.map(\.key) } else { [] }
}

/// A streamed response made of the given events, each with its `type` as the event's name.
func events(_ events: JSONValue...) -> StubResponse {
    let lines = events.map { "event: \($0["type"]?.stringValue ?? "")\ndata: \($0.text)\n\n" }
    return .eventStream(Data(lines.joined().utf8))
}

/// A lifecycle event, such as `response.completed`, with the response's members.
func lifecycle(_ type: String, _ response: JSONValue = [:]) -> JSONValue {
    ["type": .string(type), "response": response]
}

/// A text delta of the message at an output index.
func textDelta(_ delta: String, at index: Int = 0) -> JSONValue {
    ["type": "response.output_text.delta", "output_index": .integer(index), "content_index": 0, "delta": .string(delta)]
}

/// The event that adds or ends an output item.
func item(_ type: String, at index: Int, _ item: JSONValue) -> JSONValue {
    ["type": .string(type), "output_index": .integer(index), "item": item]
}

/// A rating whose stars have a range, which the portable schema moves into the description.
@Generable
struct Rating {
    @Guide(.range(1...5))
    var stars: Int
}

/// A tool that looks up a word.
struct LookUpTool: Tool {
    let name = "lookUp"
    let description = "Looks up a word."

    @Generable
    struct Arguments {
        var word: String
    }

    func call(arguments: Arguments) async throws -> String {
        "\(arguments.word): an oval"
    }
}
