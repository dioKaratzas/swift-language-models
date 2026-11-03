import Foundation

/// OpenAI's list of the models a key may use, `GET /v1/models`: the only list of the models OpenAI still serves, with
/// the day each shuts down.
struct OpenAIModelList: Decodable {
    struct Model: Decodable {
        let id: String
        /// Seconds since 1970.
        let created: Int
        /// The day OpenAI shuts the model down, as `yyyy-MM-dd`.
        let shutdownDate: String?

        private enum CodingKeys: String, CodingKey {
            case id, created
            case shutdownDate = "shutdown_date"
        }
    }

    let data: [Model]

    static func decoded(from data: Data) throws -> OpenAIModelList {
        try JSONDecoder().decode(OpenAIModelList.self, from: data)
    }
}
