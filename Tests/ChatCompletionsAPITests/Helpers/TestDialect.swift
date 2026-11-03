import ChatCompletionsAPI
import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import UniformTypeIdentifiers

/// A dialect that adds only what a test gives it, so the format's own behavior shows.
///
/// Its errors are the format's failures themselves, so a test can read what failed.
struct TestDialect: ChatCompletionsDialect {
    typealias Model = TestModel
    typealias ProviderError = ChatCompletionsFailure<TestDialect>
    typealias BodyExtras = JSONValue
    typealias ReplayMembers = JSONValue
    typealias ChunkExtras = TestExtras
    typealias StreamState = TestStreamState

    let setup: TestModel.Setup

    init(model: TestModel, executor: TestModel.RequestExecutor) {
        setup = model.setup
    }

    init(_ setup: TestModel.Setup = TestModel.Setup()) {
        self.setup = setup
    }

    static var name: String { "Test" }

    /// The fallbacks the test adds go after the model, as a provider may order its members.
    static var memberOrder: [MemberKey] { [.model, "models", .messages] }

    /// The members a test may leave out.
    static var listedMembers: Set<MemberKey> { [.temperature, .maxCompletionTokens, .topP] }

    var modelID: TestModelID { "vendor/model" }

    var baseURL: URL { setup.url }

    var connection: ProviderConnection {
        ProviderConnection(
            session: setup.session, authentication: RequestAuthentication(baseURL: nil) { [:] }, idleTimeout: nil, retryDelay: .zero)
    }

    func headers(_ context: HeaderContext) -> [HTTPHeaderName: String] { ["X-Test": "yes"] }

    func lists(_ member: MemberKey) -> Bool { setup.lists(member) }

    func body(_ context: BodyContext) throws(LanguageModelError) -> BodyPlan<JSONValue> {
        try setup.plan(context)
    }

    func replayMembers(_ reasoning: [ReplayedReasoning]) -> JSONValue {
        guard let member = setup.reasoningMember else { return [:] }
        return [member: .string(reasoning.map(\.text).joined())]
    }

    func streamState(_ headers: ResponseHeaders) -> TestStreamState { TestStreamState() }

    func observe(_ extras: TestExtras, into state: inout TestStreamState) -> ChunkOutput {
        state.host = extras.host ?? state.host
        return ChunkOutput(reasoning: extras.choices?.first?.delta?.reasoning)
    }

    func facts(of state: TestStreamState) -> AnswerFacts {
        var metadata: [String: any ConvertibleToGeneratedContent] = [:]
        metadata[LanguageModelMetadataKey.provider] = state.host
        return AnswerFacts(host: state.host, metadata: metadata)
    }

    func error(for failure: ChatCompletionsFailure<TestDialect>) -> MappedError<ChatCompletionsFailure<TestDialect>> {
        .provider(failure)
    }
}

/// The host the chunks named.
struct TestStreamState: Sendable {
    var host: String?
}

/// The members of a chunk only the test dialect reads: the host, and plain reasoning text in the delta.
struct TestExtras: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let reasoning: String?
        }

        let delta: Delta?
    }

    let host: String?
    let choices: [Choice]?
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

        /// The key under which an assistant message carries the text of the reasoning it sends back, or `nil` to send
        /// none.
        var reasoningMember: String?
    }

    struct Details: ModelDetails {
        let id: TestModelID = "vendor/model"
        let displayName = "Model"
        let capabilities = LanguageModelCapabilities([.guidedGeneration, .toolCalling])
        let reasoning = ModelReasoning.unsupported
        let contextSize: Int? = 1_000
        let reasoningEfforts: [Efforts.Unsupported] = []
        let defaultReasoningEffort: Efforts.Unsupported? = nil
        let removalDate: Date? = nil
        let dataAttachmentTypes: Set<UTType> = []
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

/// A text segment.
func text(_ content: String) -> Transcript.Segment {
    .text(.init(content: content))
}

/// The messages of a request body.
func messages(_ body: JSONValue) -> [JSONValue] {
    if case .array(let messages)? = body["messages"] { messages } else { [] }
}

/// The keys of an object, in order.
func keys(_ value: JSONValue?) -> [String] {
    if case .object(let object)? = value { object.members.map(\.key) } else { [] }
}
