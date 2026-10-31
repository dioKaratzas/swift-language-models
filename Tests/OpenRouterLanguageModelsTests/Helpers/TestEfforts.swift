import LanguageModels

/// The efforts of a test model that accepts `high`, `medium` and `low`.
enum HighMediumLow: String, ModelEffort, CaseIterable, Codable {
    case high
    case medium
    case low
}

/// The efforts of a test model that accepts `high`, `low` and `none`.
enum HighLowOff: String, ModelEffort, CaseIterable, Codable {
    case high
    case low
    case off = "none"
}

/// The efforts of a test model that accepts `max`, `high`, `low` and `none`.
enum MaxHighLowOff: String, ModelEffort, CaseIterable, Codable {
    case max
    case high
    case low
    case off = "none"
}
