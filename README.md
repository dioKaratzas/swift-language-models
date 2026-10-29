# Swift Language Models

[![CI](https://github.com/dioKaratzas/swift-language-models/actions/workflows/ci.yml/badge.svg)](https://github.com/dioKaratzas/swift-language-models/actions/workflows/ci.yml)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FdioKaratzas%2Fswift-language-models%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/dioKaratzas/swift-language-models)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FdioKaratzas%2Fswift-language-models%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/dioKaratzas/swift-language-models)
[![License](https://img.shields.io/badge/license-Apache_2.0-blue.svg)](LICENSE)

Run 380+ OpenRouter models natively through Apple's Foundation Models: Apple's own `LanguageModelSession`, with
tools, guided generation, reasoning, caching, routing and attachments.

```swift
import FoundationModels
import OpenRouterLanguageModels

let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, apiKey: { try await keyStore.openRouterKey() })
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: "Plan a three-day trip to Kyoto.")
```

Foundation Models 27 lets any type conform to its `LanguageModel` protocol. This package adds those conformances for
remote providers, and nothing else. Your app keeps `import FoundationModels` and Apple's own sessions, transcripts,
tools, guided generation, Dynamic Profiles and reasoning levels. Moving a session between Apple's on-device model and
a remote one changes only its `model:`.

* [Foundation Models native](#foundation-models-native)
* [Providers](#providers)
* [Requirements](#requirements)
* [Installation](#installation)
* [Usage](#usage)
* [OpenRouter](#openrouter)
* [Documentation](#documentation)
* [Testing](#testing)
* [Contributing](#contributing)
* [License](#license)

## Foundation Models native

This package builds on Apple's framework rather than replacing it.
[AnyLanguageModel](https://github.com/huggingface/AnyLanguageModel) takes the other approach: it reimplements the
Foundation Models API, and you change `import FoundationModels` to `import AnyLanguageModel`. That lets it run on
iOS 17, macOS 14 and Linux, and offer more providers today, including on-device backends such as MLX and llama.cpp.
Choose it when you need those.

This package needs OS 27, and in exchange there's no second API to learn or wait on. Sessions, transcripts, Dynamic
Profiles and `LanguageModelError` are Apple's own, so new framework features reach remote models without a copy to
update, and code written for Apple's models works unchanged.

Vendors ship native packages for their own models too, such as Anthropic's
[ClaudeForFoundationModels](https://github.com/anthropics/ClaudeForFoundationModels). OpenRouter reaches those
vendors' models, and many others, through one API.

## Providers

| Provider | Module | Status | Notes |
|---|---|---|---|
| [OpenRouter](https://openrouter.ai) | `OpenRouterLanguageModels` | Available | 380+ models from Anthropic, OpenAI, Google, Mistral, DeepSeek, Qwen and others, in a typed catalog |

Each provider is its own library product, so an app builds only the providers it imports. The `LanguageModels` module
holds what they share: model details and typed reasoning efforts. More providers will follow.

## Requirements

- iOS 27.0, macOS 27.0, visionOS 27.0 or watchOS 27.0. PDF, audio and video attachments and generated images need
  27.2.
- Xcode 27.0 or later, with Swift 6.4. File, audio and video attachments and generated data need Xcode 27.2 at build
  time, since earlier SDKs lack Foundation Models' data attachments and data entries; built with an earlier Xcode, the
  package leaves them out.

Foundation Models' `LanguageModel` isn't available on tvOS or Linux, so neither is this package.

## Installation

In Xcode, choose **File ▸ Add Package Dependencies…** and enter:

> https://github.com/dioKaratzas/swift-language-models

In a `Package.swift`, add the package:

```swift
dependencies: [
  .package(url: "https://github.com/dioKaratzas/swift-language-models", from: "0.1.0")
]
```

Then add a provider's product, and `LanguageModels` for typed reasoning efforts, to each target that uses them:

```swift
.product(name: "OpenRouterLanguageModels", package: "swift-language-models"),
.product(name: "LanguageModels", package: "swift-language-models"),
```

The modules don't re-export each other, so import each one a file uses. A provider's module alone covers its own types,
including ids and other words written as string literals, such as `"anthropic/claude-haiku-5.5"`. Import
`LanguageModels` where a file uses typed efforts, such as `model(_:effort:)`.

## Usage

This section is plain Foundation Models, and works the same with every provider. The examples continue from the one
at the top.

### Streaming

```swift
for try await snapshot in session.streamResponse(to: "Write a haiku about the sea.") {
    print(snapshot.content)
}
```

### Guided generation

```swift
@Generable
struct Itinerary {
    @Guide(description: "A short title for the trip")
    var title: String

    @Guide(description: "One plan per day", .count(3))
    var days: [String]
}

let itinerary = try await session.respond(to: "Plan three days in Kyoto.", generating: Itinerary.self).content
```

It works with every model whose `capabilities` include `.guidedGeneration`.

### Tools

```swift
struct WeatherTool: Tool {
    let description = "Gets the current temperature in a city."

    @Generable
    struct Arguments {
        @Guide(description: "The city's name")
        var city: String
    }

    func call(arguments: Arguments) async throws -> String {
        "It's 21°C in \(arguments.city)."
    }
}

let session = LanguageModelSession(model: model, tools: [WeatherTool()])
let response = try await session.respond(to: "Do I need a jacket in Athens today?")
```

### Reasoning levels

Apple's reasoning levels work with every model that reasons. The provider maps `.light`, `.moderate` and `.deep` to
the nearest effort the model accepts:

```swift
let response = try await session.respond(
    to: "How many weekdays are in March 2027?",
    contextOptions: ContextOptions(reasoningLevel: .deep)
)
```

For one of the model's own efforts, set the model on a Dynamic Profile with `model(_:effort:)` from `LanguageModels`.
Each catalog model's effort type lists exactly the levels that model accepts, so any other level fails to compile:

```swift
import LanguageModels

struct TutorProfile: LanguageModelSession.DynamicProfile {
    let model: OpenRouterLanguageModel<Efforts.MaxXhighHighMediumLowOff>  // Claude Haiku 5.5's levels

    var body: some LanguageModelSession.DynamicProfile {
        LanguageModelSession.Profile { Instructions("You are a careful math tutor.") }
            .model(model, effort: .xhigh)
    }
}

let session = LanguageModelSession(profile: TutorProfile(model: model))
```

The effort becomes the profile's reasoning level, so `reasoningLevel(_:)` and a request's `ContextOptions` still
override it. The model's reasoning arrives in the transcript as reasoning entries.

### Attachments

Prompts take Apple's attachments. Images work from OS 27.0:

```swift
let response = try await session.respond {
    "What did I spend on dinner?"
    Attachment(receipt).label("receipt")
}
```

From OS 27.2, in apps built with Xcode 27.2, data attachments add PDFs, audio, video and text. `FileAttachment` reads
a file and tells its type from its extension, or wraps bytes of a type you name, such as
`FileAttachment(receipt, type: .pdf)`:

```swift
import LanguageModels

if #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *) {
    let lease = try FileAttachment(contentsOf: leaseURL)
    let response = try await session.respond {
        "When does the lease end?"
        Attachment(lease).label("lease.pdf")
    }
}
```

`model.supportsDataAttachmentType(_:)` says whether a model takes a kind of data. A request with an attachment the
model doesn't take throws `LanguageModelError` before anything is sent.

### Errors

Providers throw Foundation Models' own `LanguageModelError` wherever it has a case, so the same `catch` works for every
model:

```swift
do {
    let response = try await session.respond(to: "Summarize our conversation.")
    print(response.content)
} catch LanguageModelError.rateLimited(let limit) {
    print("Try again after \(limit.resetDate ?? .now).")
} catch LanguageModelError.contextSizeExceeded(let exceeded) {
    print("The conversation needs \(exceeded.tokenCount) tokens, and the model takes \(exceeded.contextSize).")
}
```

Failures that `LanguageModelError` has no case for, such as a rejected API key, throw the provider's own error type.

### Logging

Each request logs what it sends and leaves out, its retries, which model and host answered, how it failed and how
long it took, under the subsystem `com.niosoft.swift-language-models`. It never logs keys, prompts, answers, tool calls
or attachments. Watch it in Xcode's console, or in Terminal:

```sh
log stream --level debug --predicate 'subsystem == "com.niosoft.swift-language-models"'
```

The system keeps debug messages only while a tool shows them, so logging costs little. To log less, set a level once:

```swift
import LanguageModels

LanguageModelsLogging.level = .error  // Only failed requests; .off logs nothing.
```

In a debug build, Xcode shows a purple runtime warning when a request leaves out a setting the model doesn't take,
or changes another from what the app asked for. `.off` silences these too.

## OpenRouter

`OpenRouterLanguageModel` reaches every model on [OpenRouter](https://openrouter.ai) with one API key.

### API keys

`apiKey` is a closure that's called for every request, and the key is never stored. Never ship a key inside an app,
where anyone can extract it. During development, read it from the environment:

```swift
let model = OpenRouterLanguageModel(.openaiGpt4_1Nano, apiKey: {
    ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? ""
})
```

In production, either let people bring their own key, kept in the Keychain and returned from the closure, or ship
without a key: point `baseURL` at your own server, which adds the key and forwards the request to OpenRouter.

```swift
let model = OpenRouterLanguageModel(
    .openaiGpt4_1Nano,
    baseURL: URL(string: "https://api.example.com/openrouter/"),
    apiKey: { try await account.shortLivedToken() }
)
```

Requests then go to `chat/completions` under `baseURL`, with the closure's token as the bearer token, and follow
redirects only to the same host.

### The model catalog

Every model OpenRouter lists is a static member of `OpenRouterModel`, with its context size, parameters, input and
output kinds, reasoning efforts and prices:

```swift
let haiku = OpenRouterModel.anthropicClaudeHaiku5_5
haiku.contextSize                     // 1_000_000
haiku.pricing?.prompt                 // 0.0000001, in US dollars per token
haiku.capabilities.contains(.vision)  // true
haiku.reasoningEfforts                // [.max, .xhigh, .high, .medium, .low, .off]
```

For models picked at runtime, such as from a list people choose from, `catalogModels` lists every model, and
`init(catalogID:)` finds one by its id:

```swift
let visionModels = OpenRouterModel.catalogModels.filter { $0.capabilities.contains(.vision) }
let picked = OpenRouterModel(catalogID: "anthropic/claude-haiku-5.5")
```

A request sends only the settings the model lists, so a host never rejects one it doesn't take. `pricing` also has
cache, reasoning, image and search prices, and `prices(forPromptTokens:at:)` applies long-prompt and off-peak rates.

### Prompt caching and the response cache

Hosts such as OpenAI, Google, DeepSeek and xAI cache long prompts on their own. Anthropic, for Claude, and Alibaba, for
Qwen, cache only prompts a request marks: a five-minute cache costs 1.25× the input price to write and 0.1× to read, so
it pays for itself on the first reuse.

`cacheControl` is `.automatic` by default. It marks a request for five minutes only when every model the request may
reach, fallbacks included, caches only marked prompts. Any other request goes unmarked, so hosts that cache on their
own are left alone, and a Gemini fallback never switches to Gemini's explicit caching, which bills storage. To mark
every request, whatever its models, and keep the cache for an hour:

```swift
let model = OpenRouterLanguageModel(
    .anthropicClaudeHaiku5_5,
    fallbacks: .openaiGpt5Mini,
    cacheControl: .always(timeToLive: .oneHour),
    apiKey: { try await keyStore.openRouterKey() }
)
```

`.automatic(timeToLive: .oneHour)` keeps the default's rule with an hour's cache, and `nil` sends no marks. A
session's requests return to the host that cached its prompt. `response.usage.input.cachedTokenCount` counts the tokens
read from the cache, and `response.usage.openRouter.cacheWriteTokenCount` the tokens written.
[Caching](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/caching)
lists what each host charges.

The response cache is OpenRouter's own. A request that repeats an earlier one, with the same key and body, gets the
earlier answer back at no cost, without reaching a host:

```swift
var model = OpenRouterLanguageModel(.openaiGpt4_1Nano, apiKey: { try await keyStore.openRouterKey() })
model.responseCache = OpenRouterResponseCache(timeToLive: .seconds(600))
```

A hit repeats the kept answer whatever the temperature or seed, until it expires.

### Routing and fallbacks

`routing` chooses which of a model's hosts OpenRouter may use, and `fallbacks:` lists models to try, in order, when the
model fails for any reason, such as downtime, a rate limit or a prompt too long for its context:

```swift
let model = OpenRouterLanguageModel(
    .anthropicClaudeHaiku5_5,
    fallbacks: .openaiGpt5Mini, .googleGemini3_1FlashLite,
    routing: OpenRouterRouting(dataCollection: .deny, requiresZeroDataRetention: true, sort: .price),
    apiKey: { try await keyStore.openRouterKey() }
)
```

Any of the models may answer, so the model's capabilities, and each request, narrow to what all of them support. The
answer's `openRouter.model` names the model that answered.

OpenRouter calls the hosts that serve a model its providers, so the package keeps that word wherever it names a host:
`OpenRouterProviderName`, `allowedProviders`, `OpenRouterError.providerName` and the `provider` metadata key.

<details>
<summary>More routing settings</summary>

`OpenRouterRouting` also sets the hosts to try first, allow or ignore, whether to fall back to other hosts, allowed
quantizations, the most to pay per token or request, preferred throughput and latency percentiles, and the `:nitro` and
`:floor` variants. See
[`OpenRouterRouting`](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/openrouterrouting).

</details>

### Server tools and citations

Server tools run on OpenRouter while the model answers, and the app implements nothing: `.webSearch`, `.webFetch`,
`.datetime`, and `.advisor` and `.subagent`, which consult or delegate to another model. A web search's cited pages
come back on the response entry:

```swift
let model = OpenRouterLanguageModel(
    .openaiGpt5Mini,
    serverTools: [.webSearch(maximumResults: 5), .webFetch(), .datetime(timeZone: .current)],
    apiKey: { try await keyStore.openRouterKey() }
)
let response = try await LanguageModelSession(model: model).respond(to: "What changed in Swift this month?")

for case .response(let answer) in response.transcriptEntries {
    for citation in answer.openRouter.citations {
        print(citation.title ?? "Untitled", citation.url)
    }
}
```

Searches, fetches and calls to other models cost extra, on top of the model's tokens. The session's own tools keep
working alongside them.

<details>
<summary>Advisors and subagents</summary>

```swift
let model = OpenRouterLanguageModel(
    .openaiGpt5Mini,
    serverTools: [
        .advisor(model: "~anthropic/claude-opus-latest", forwardsTranscript: true),
        .subagent(model: "~anthropic/claude-haiku-latest", tools: [.webSearch()]),
    ],
    apiKey: { try await keyStore.openRouterKey() }
)
```

The model asks the advisor for advice while it answers, and hands self-contained tasks to the subagent. Each call is
billed at that model's price.

</details>

### Attachments and generated images

- An image goes as a JPEG, upright, at most 2,048 pixels on its longer side, and without metadata such as where a photo
  was taken.
- OpenRouter reads a PDF for a model that can't, with Mistral's OCR at a price per page. Set `options.pdfEngine` to
  `.cloudflareAI` for a free engine.
- Each request sends the whole transcript, so an attachment is billed again on later turns, at the cached price where
  the host caches prompts.

A model that generates images, such as Gemini 2.5 Flash Image, returns each image as a data entry, from OS 27.2 in
apps built with Xcode 27.2:

```swift
import UniformTypeIdentifiers

let artist = OpenRouterLanguageModel(.googleGemini2_5FlashImage, apiKey: { try await keyStore.openRouterKey() })
let response = try await LanguageModelSession(model: artist).respond(to: "Draw a lighthouse at dusk.")

if #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *) {
    for case .data(let image) in response.transcriptEntries where image.contentType.conforms(to: .image) {
        print(image.contentType, image.content.count)
    }
}
```

### Response metadata

The usage of an answer carries its cost, and the entry that ends it carries the host, the model that answered, its
response id and the finish reason. `openRouter` reads them as typed values, with amounts in US dollars as `Decimal`:

```swift
let response = try await session.respond(to: "Plan dinner.")

if let dollars = response.usage.openRouter.cost {
    print("It cost $\(dollars).")
}
if case .response(let answer)? = response.transcriptEntries.last {
    if let host = answer.openRouter.provider {
        print("\(host) answered.")
    }
    if answer.openRouter.finishReason == .length {
        print("The answer was cut short at its token limit.")
    }
}
```

They also hold the host's own charge, cache writes, server-tool calls, what the response cache did and, with
`options.includesRouterMetadata`, how OpenRouter routed the request. The metadata stores them under the keys
`OpenRouterMetadataKey` names: keys for facts every model reports, such as `cost` and `provider`, have no prefix; keys
only OpenRouter has start with `openRouter.`.

### Errors

Rate limits, oversized contexts, content filters, refusals and timeouts throw `LanguageModelError`. Anything else
throws `OpenRouterError`, with its HTTP status, code, host and retry delay:

```swift
do {
    try await session.respond(to: "Plan dinner.")
} catch let error as OpenRouterError where error.code == .paymentRequired {
    print("The account is out of credits.")
}
```

<details>
<summary>How errors map</summary>

| OpenRouter | Thrown |
|---|---|
| A context too long for the model | `LanguageModelError.contextSizeExceeded` |
| 429, or too many requests in flight | `LanguageModelError.rateLimited`, with the reset date |
| A content policy or moderation flag | `LanguageModelError.guardrailViolation` |
| A refusal | `LanguageModelError.refusal` |
| 408, 524, or a timed-out connection | `LanguageModelError.timeout` |
| Anything else, such as 401 or 402 | `OpenRouterError` |

A 502, 503, 504 or 529 is retried once, before any data arrives. A `LanguageModelError` carries the HTTP status,
OpenRouter's error code and the host in its metadata, under `OpenRouterMetadataKey.status`, `.errorCode` and
`.provider`.

</details>

<details>
<summary>Other settings</summary>

`OpenRouterOptions` holds the settings only OpenRouter has, such as penalties, stop sequences, verbosity, service tier
and the PDF engine. `app` names the app, to credit it in OpenRouter's rankings and app marketplace.

```swift
let model = OpenRouterLanguageModel(
    .openaiGpt5Mini,
    options: OpenRouterOptions(stopSequences: ["END"], verbosity: .low, pdfEngine: .cloudflareAI),
    app: OpenRouterApp(name: "Trip Planner", url: URL(string: "https://example.com"), categories: [.personalAgent]),
    apiKey: { try await keyStore.openRouterKey() }
)
```

`GenerationOptions` map to OpenRouter's parameters: `temperature`, `samplingMode`, `maximumResponseTokens` and
`toolCallingMode`. [Mapping](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/mapping)
lists how every request, answer and error translates.

</details>

## Documentation

The documentation for each module is on the Swift Package Index:

* [`OpenRouterLanguageModels`](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels):
  the OpenRouter model, its catalog and settings.
* [`LanguageModels`](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels): model
  details and typed reasoning efforts.

For sessions, tools, guided generation and profiles, see Apple's
[Foundation Models documentation](https://developer.apple.com/documentation/foundationmodels).

## Testing

```sh
swift test
```

The test suites run offline, against stubbed HTTP responses. Live suites, which call real models through OpenRouter,
run only when `OPENROUTER_API_KEY` is set. A full live run costs a few cents.

```sh
OPENROUTER_API_KEY=… swift test
```

A sweep of each vendor's cheapest model runs only when `LIVE_SWEEP` is set as well.

## Contributing

Issues and pull requests are welcome. For a larger change, such as a new provider, open an issue first. Before a pull
request, run `swift build` and `swift test`, and format the code with swift-format, which reads `.swift-format`.

The files in `Catalogs/` and the `Generated/` sources are generated, so don't edit them by hand. To refresh them from
OpenRouter's model list, run:

```sh
swift package plugin --allow-network-connections all:443 --allow-writing-to-package-directory generate-model-catalog
```

A provider is a module named `<Vendor>LanguageModels`, whose `<Vendor>LanguageModel` conforms to
`DetailedLanguageModel`.

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE).
