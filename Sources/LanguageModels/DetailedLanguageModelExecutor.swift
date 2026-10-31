import Foundation
public import FoundationModels

/// The executor of every ``DetailedLanguageModel``, which checks each request before the model's request executor
/// sends it.
///
/// Foundation Models creates the executor from the model's `executorConfiguration` and calls it for each answer. For
/// each model the request may reach, the model and then its fallbacks, whose ``ModelDetails/removalDate`` is set, the
/// executor logs an error and, in a debug build, shows a runtime warning, since the provider no longer lists that
/// model and the request may fail. Then it calls the request executor's
/// ``DetailedLanguageModelRequestExecutor/execute(_:model:streamingInto:)``.
///
/// A provider module writes only the request executor. ``DetailedLanguageModel`` requires this executor, so no
/// provider module can leave the checks out.
public struct DetailedLanguageModelExecutor<RequestExecutor: DetailedLanguageModelRequestExecutor>: LanguageModelExecutor {
    /// The model the executor answers with.
    public typealias Model = RequestExecutor.Model

    /// What the request executor needs to send requests.
    public typealias Configuration = RequestExecutor.Configuration

    private let requestExecutor: RequestExecutor

    /// Creates an executor and its request executor.
    ///
    /// - Parameter configuration: What the request executor needs to send requests.
    /// - Throws: What the request executor's initializer throws.
    public init(configuration: Configuration) throws {
        requestExecutor = try RequestExecutor(configuration: configuration)
    }

    /// Reports each model the request may reach that its provider stopped listing, then sends the request.
    ///
    /// - Parameters:
    ///   - request: The transcript, tools, schema and options to send.
    ///   - model: The model to answer with.
    ///   - channel: Where the answer's events go.
    /// - Throws: What the request executor throws.
    public func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: Model,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws {
        let requestID = String(request.id.uuidString.prefix(8))
        for removed in model.removedModels {
            removed.report(request: requestID)
        }
        try await requestExecutor.execute(request, model: model, streamingInto: channel)
    }
}
