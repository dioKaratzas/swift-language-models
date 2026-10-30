import Foundation
import OpenRouterLanguageModels

/// What OpenRouter charges for its models now, from its public model list, which needs no key.
///
/// The list is fetched once per test run, on the first read.
enum LivePrices {
    /// Each model's prompt and completion prices, by id. A model whose price depends on the request, such as a router,
    /// isn't listed.
    ///
    /// - Throws: An error when OpenRouter can't be reached or its list doesn't decode.
    static var all: [OpenRouterModelID: OpenRouterPricing] {
        get async throws { try await fetch.value }
    }

    private static let fetch = Task { try await download() }

    private static func download() async throws -> [OpenRouterModelID: OpenRouterPricing] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else { throw FetchError("The address is invalid.") }
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode
        guard status == 200 else { throw FetchError("OpenRouter answered with HTTP \(status.map(String.init) ?? "nothing").") }
        let models = try JSONDecoder().decode(ModelList.self, from: data).data
        return Dictionary(
            models.compactMap { model in
                guard let pricing = model.pricing, let prompt = price(pricing.prompt), let completion = price(pricing.completion)
                else { return nil }
                return (model.id, OpenRouterPricing(prompt: prompt, completion: completion))
            }
        ) { first, _ in first }
    }

    /// A price from OpenRouter's decimal text, or `nil` for a negative one, which OpenRouter sends when the price depends
    /// on the request.
    private static func price(_ text: String) -> Decimal? {
        Decimal(string: text).flatMap { $0 < 0 ? nil : $0 }
    }

    /// The body of `GET /models`, reduced to the prices.
    private struct ModelList: Decodable {
        struct Model: Decodable {
            struct Pricing: Decodable {
                let prompt: String
                let completion: String
            }

            let id: OpenRouterModelID
            let pricing: Pricing?
        }

        let data: [Model]
    }

    /// Why the list couldn't be fetched.
    private struct FetchError: Error, CustomStringConvertible {
        let description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
