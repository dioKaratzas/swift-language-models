public import LanguageModels

/// The precision of a host's model weights, such as `fp8`.
public struct OpenRouterQuantization: ProviderVocabulary {
    /// 4-bit integers.
    public static let int4: Self = "int4"

    /// 8-bit integers.
    public static let int8: Self = "int8"

    /// 4-bit floating point.
    public static let fp4: Self = "fp4"

    /// 4-bit microscaling floating point.
    public static let mxfp4: Self = "mxfp4"

    /// NVIDIA's 4-bit floating point.
    public static let nvfp4: Self = "nvfp4"

    /// 6-bit floating point.
    public static let fp6: Self = "fp6"

    /// 8-bit floating point.
    public static let fp8: Self = "fp8"

    /// 8-bit microscaling floating point.
    public static let mxfp8: Self = "mxfp8"

    /// 16-bit floating point.
    public static let fp16: Self = "fp16"

    /// 16-bit brain floating point.
    public static let bf16: Self = "bf16"

    /// 32-bit floating point.
    public static let fp32: Self = "fp32"

    /// A precision the host doesn't report.
    public static let unknown: Self = "unknown"

    /// The precision's name in OpenRouter's API.
    public let rawValue: String

    /// Creates a precision from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"fp8"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
