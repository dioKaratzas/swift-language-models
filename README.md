<h1>
  <img alt="Swift Language Models icon" src="./assets/icon.png" width="76" height="76" valign="middle">
  &nbsp;Swift Language Models
</h1>

[![CI](https://github.com/dioKaratzas/swift-language-models/actions/workflows/ci.yml/badge.svg)](https://github.com/dioKaratzas/swift-language-models/actions/workflows/ci.yml)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FdioKaratzas%2Fswift-language-models%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/dioKaratzas/swift-language-models)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FdioKaratzas%2Fswift-language-models%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/dioKaratzas/swift-language-models)
[![License](https://img.shields.io/badge/license-Apache_2.0-blue.svg)](LICENSE)

One Foundation Models API for every provider's language models. Apple's `LanguageModelSession`, with its transcripts,
tools, `@Generable` guided generation, Dynamic Profiles and reasoning levels, is the one interface, and provider
modules plug other models into it, so Claude, GPT, Gemini, DeepSeek, Qwen, Llama and Mistral run through the same
session as Apple's on-device model. OpenRouter is the first provider module, and more are coming.

* [Quick start](#quick-start)
* [How it works](#how-it-works)
* [Provider modules](#provider-modules)
* [Features](#features)
* [Requirements](#requirements)
* [Installation](#installation)
* [Usage](#usage)
* [Example app](#example-app)
* [Documentation](#documentation)
* [Testing](#testing)
* [Contributing](#contributing)
* [Related projects](#related-projects)
* [License](#license)

## Quick start

```swift
import FoundationModels
import OpenRouterLanguageModels

let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, apiKey: { try await keyStore.openRouterKey() })
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: "Plan a three-day trip to Kyoto.")
print(response.content)
```

`apiKey` is a closure, called for every request; the key is never stored or logged. Return it from the Keychain, or
point `baseURL` at your own server and return a short-lived token for it, so no key ships inside the app.

## How it works

Foundation Models 27 lets any type conform to its `LanguageModel` protocol, as Apple's
[Running a Core AI model in a Foundation Models session](https://developer.apple.com/documentation/foundationmodels/running-a-core-ai-model-in-a-foundation-models-session)
shows. This package adds those conformances for other services, and nothing else: your app keeps
`import FoundationModels` and Apple's own sessions, transcripts, tools, guided generation, Dynamic Profiles and
`LanguageModelError`, so new framework features reach every model without a copy to update. Moving a session between
Apple's on-device model and a remote one changes only its `model:`.

The package has two kinds of module. `LanguageModels` is the core that every provider module shares:
`DetailedLanguageModel` and `ModelDetails`, the executor every provider module's model uses, typed reasoning efforts,
`FileAttachment` and `LanguageModelsLogging`. Each provider module connects one service, such as OpenRouter: its model
conforms to `DetailedLanguageModel`, and its request executor sends the requests, maps the service's errors to
`LanguageModelError`, and reports usage, reasoning and tool calls in Apple's transcript. A provider module re-exports
the core, so one import is enough.

## Provider modules

| Product | Service | Models |
|---|---|---|
| `OpenRouterLanguageModels` | [OpenRouter](https://openrouter.ai) | Every model OpenRouter lists, from Anthropic, OpenAI, Google, DeepSeek, Qwen, Meta, Mistral and others, in a typed catalog |

Each provider module is its own library product, so an app builds only the modules it imports. Open a module for its
keys, model catalog and features.

A provider module whose service lists its models ships them as a typed catalog, which a bot in this repository keeps
current. [Model catalogs](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/modelcatalogs)
says what happens when a service adds, retires or stops listing a model, and which release each change needs.

<details>
<summary><b>OpenRouter</b>: every model OpenRouter lists, from Anthropic, OpenAI, Google, DeepSeek, Qwen, Meta, Mistral and others</summary>

`OpenRouterLanguageModel` reaches every model on [OpenRouter](https://openrouter.ai) with one API key.

#### API keys

`apiKey` is a closure that's called for every request, and the key is never stored. Never ship a key inside an app,
where anyone can extract it. During development, read it from the environment, set in a scheme you leave unshared, so
the key stays out of git:

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

#### The model catalog

Every model OpenRouter lists is a static member of `OpenRouterModel`, with its context size, output limit, parameters,
input and output kinds and reasoning efforts:

```swift
let haiku = OpenRouterModel.anthropicClaudeHaiku5_5
print(haiku.contextSize ?? 0)                  // The context window, in tokens
print(haiku.maximumOutputTokens ?? 0)          // The most tokens one answer can have
print(haiku.capabilities.contains(.vision))    // Whether it reads images
print(haiku.reasoningEfforts.map(\.rawValue))  // The efforts it accepts, highest first
```

Each model also has an effort type of its own, which lists the levels it accepts, as
[Reasoning effort](#reasoning-effort) shows.

For models picked at runtime, such as from a list people choose from, `catalogModels` lists every model, and
`init(catalogID:)` finds one by its id:

```swift
let visionModels = OpenRouterModel.catalogModels.filter { $0.capabilities.contains(.vision) }
let picked = OpenRouterModel(catalogID: "anthropic/claude-haiku-5.5")
```

A model OpenRouter will retire is marked `deprecated`, with the day, and so is one it stops listing, as
[Choosing a model](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/choosingamodel#How-the-catalog-stays-current)
describes.

A sampling or output setting, such as `temperature`, `stop` or `verbosity`, goes out only when the model lists its
parameter, so a host never rejects one it doesn't take. The catalog keeps no prices, since OpenRouter changes them
often; `response.usage.openRouter.cost` reports what each request cost.

#### Providers and today's prices

What changes often comes from OpenRouter when you ask, without an API key. `providers()` lists each host that serves a
model, once for each region, tier or precision, with its prices, limits and recent uptime, and `currentPricing()` reads
the model's prices today:

```swift
let providers = try await OpenRouterModel.anthropicClaudeHaiku5_5.providers()
let europe = providers.filter { $0.tag.rawValue.hasSuffix("/europe") }.map(\.tag)  // Such as google-vertex/europe
let model = OpenRouterLanguageModel(
    .anthropicClaudeHaiku5_5,
    routing: OpenRouterRouting(order: europe),
    apiKey: { try await keyStore.openRouterKey() }
)

if let pricing = try await model.currentPricing() {
    print(pricing.prompt * 1_000_000)  // US dollars per million prompt tokens
}
```

On a language model, they use its key, so each host's latency and throughput come too. Answers are kept for a minute,
so a list that asks for each row doesn't fetch them again.

#### Prompt caching and the response cache

Hosts such as OpenAI, Google, DeepSeek and xAI cache long prompts on their own. Anthropic, for Claude, and Alibaba, for
Qwen, cache only prompts a request marks: a five-minute cache costs 1.25× the input price to write and a fraction of it
to read, so it pays for itself on the first reuse.

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
says how each host caches, and `currentPricing()` reads a model's cache prices today.

The response cache is OpenRouter's own. A request that repeats an earlier one, with the same key and body, gets the
earlier answer back at no cost, without reaching a host:

```swift
var model = OpenRouterLanguageModel(.openaiGpt4_1Nano, apiKey: { try await keyStore.openRouterKey() })
model.responseCache = OpenRouterResponseCache(timeToLive: .seconds(600))
```

A hit repeats the kept answer whatever the temperature or seed, until it expires.

#### Routing and fallbacks

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

`OpenRouterRouting` also sets the hosts to try first, allow or ignore, whether to fall back to other hosts, allowed
quantizations, the most to pay per token or request, preferred throughput and latency percentiles, and the `:nitro` and
`:floor` variants. See
[`OpenRouterRouting`](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/openrouterrouting).

#### Server tools and citations

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

Advisors and subagents are server tools too:

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

#### Attachments and generated images

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

#### Response metadata

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

#### Errors

Rate limits, oversized contexts, content filters, refusals and timeouts throw `LanguageModelError`. Anything else
throws `OpenRouterError`, with its HTTP status, code, host and retry delay:

```swift
do {
    try await session.respond(to: "Plan dinner.")
} catch let error as OpenRouterError where error.code == .paymentRequired {
    print("The account is out of credits.")
}
```

How errors map:

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

#### Other settings

`OpenRouterOptions` holds the settings only OpenRouter has, such as penalties, stop sequences, verbosity, service tier
and the PDF engine. `app` names the app, to credit it in OpenRouter's rankings and app marketplace, which OpenRouter
does only when the app's `url` is set.

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

The [OpenRouter documentation](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels)
has an article for each of these.

</details>

## Features

- **Foundation Models native.** Sessions, transcripts, tools, guided generation, Dynamic Profiles and reasoning
  levels are Apple's own, and work the same with every provider.
- **Typed model catalog.** Every OpenRouter model is a static member of `OpenRouterModel`, such as
  `.anthropicClaudeHaiku5_5`, with its context size, output limit, parameters, data kinds and reasoning efforts;
  `catalogModels` and `init(catalogID:)` serve models picked at runtime.
- **Typed reasoning efforts.** `model.reasoningLevel(.xhigh)` and `.model(model, effort: .xhigh)` take only the levels
  the model accepts. Apple's `.light`, `.moderate` and `.deep` still work, sent as the nearest level the model
  accepts.
- **Fallbacks and provider routing.** Models to try in order when one fails, and which hosts may serve them, by
  price, throughput, data policy, region or quantization.
- **Prompt caching.** Prompts are marked for the hosts that cache only marked prompts, such as Anthropic's, and
  OpenRouter's response cache answers a repeated request at no cost.
- **Server tools.** Web search, web fetch, the date and time, and advisor and subagent models run on OpenRouter while
  the model answers, with cited pages on the response.
- **Routers.** `openrouter/auto` and `openrouter/pareto-code` take their settings through `OpenRouterOptions`, and the
  answer names the model the router picked.
- **Attachments.** Images from OS 27.0; PDFs, audio, video and text through `FileAttachment` from OS 27.2; and
  generated images back as data entries.
- **Live model details and pricing.** `providers()`, `currentDetails()` and `currentPricing()` read each host's
  prices, limits and uptime, and today's prices, from OpenRouter.
- **Response metadata.** The cost, host, model, response id and finish reason of each answer, as typed values.
- **Transport.** A proxy through `baseURL`, a `URLSession` of your own and `idleTimeout`, with redirects only to the
  same host.
- **Errors.** Rate limits, oversized contexts, content filters, refusals and timeouts throw `LanguageModelError`;
  everything else throws the provider module's own error, with its status, code and retry delay.
- **Logging.** Each request logs what it sends and leaves out, its retries and how it ended, never keys, prompts or
  answers, and a debug build shows an Xcode runtime warning for a setting a model doesn't take.
- **Testing and evaluation.** Any model can be the model under test, the judge or the sample generator in Apple's
  Evaluations framework, and a scripted model keeps unit tests offline.

## Requirements

- iOS 27.0, macOS 27.0, visionOS 27.0 or watchOS 27.0. PDF, audio, video and text attachments and generated images
  need 27.2.
- Xcode 27.0 or later, with Swift 6.4. PDF, audio, video and text attachments and generated images also need Xcode 27.2
  at build time, since earlier SDKs lack Foundation Models' data attachments and data entries; built with an earlier
  Xcode, the package leaves them out.

Foundation Models' `LanguageModel` isn't available on tvOS or Linux, so neither is this package.

## Installation

In Xcode, choose **File ▸ Add Package Dependencies…** and enter:

> https://github.com/dioKaratzas/swift-language-models

In a `Package.swift`, add the package:

```swift
dependencies: [
  .package(url: "https://github.com/dioKaratzas/swift-language-models", from: "0.3.2")
]
```

Then add the provider module's product to each target that uses it:

```swift
.product(name: "OpenRouterLanguageModels", package: "swift-language-models")
```

`import OpenRouterLanguageModels` is all a file needs besides `import FoundationModels`, and `import Foundation` for
types such as `URL`. It re-exports `LanguageModels`, the core every provider module shares, so typed reasoning efforts,
`FileAttachment` and the model details come with it.

## Usage

Sessions, streaming, tools and guided generation are plain Foundation Models, and work the same with every provider.
The examples continue from the quick start.

### Streaming

```swift
for try await snapshot in session.streamResponse(to: "Write a haiku about the sea.") {
    print(snapshot.content)
}
```

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

It works with every model whose `capabilities` include `.guidedGeneration`, which a provider module reports only when
its service holds the answer to the schema, as strict structured outputs do. A guided request to any other model
throws `LanguageModelError.unsupportedCapability` before it's sent.
[Tools and guided generation](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/toolsandguidedgeneration)
says how OpenRouter models send tools and schemas.

### Reasoning effort

Each model accepts its own reasoning levels: Claude Haiku 5.5 takes `max`, `xhigh`, `high`, `medium`, `low` and `off`,
and GPT-5 Mini takes `high`, `medium`, `low` and `minimal`. `model.reasoningLevel(_:)` takes only the
levels the model accepts, so code completion offers exactly those:

```swift
let response = try await session.respond(
    to: "How many weekdays are in March 2027?",
    contextOptions: ContextOptions(reasoningLevel: model.reasoningLevel(.xhigh))
)
```

#### See a model's levels

- **In Xcode**, type `model.reasoningLevel(.` and code completion lists exactly the model's levels.
- **At runtime**, the model's details list them, highest first:

  ```swift
  print(model.details.reasoningEfforts.map { "\($0)" })  // ["max", "xhigh", "high", "medium", "low", "none"]
  ```

- **In the type**, each model has an effort type of its own, named after the model: Haiku 5.5's is
  `Efforts.Of<OpenRouterModels.AnthropicClaudeHaiku5_5>`. Option-click the model in Xcode to see it. The type stays
  the same when OpenRouter changes the model's levels, so code that spells it keeps compiling.

A model that doesn't reason, or picks its own level, has an effort type with no levels.

#### Set a level for a whole session

`model(_:effort:)` sets a model on a Dynamic Profile at one of its own levels, checked the same way. A profile that's
generic over its model works with any model, and the effort's type follows from the model you pass:

```swift
struct TutorProfile<Model: DetailedLanguageModel>: LanguageModelSession.DynamicProfile {
    let model: Model
    let effort: Model.Details.Effort

    var body: some LanguageModelSession.DynamicProfile {
        LanguageModelSession.Profile { Instructions("You are a careful math tutor.") }
            .model(model, effort: effort)
    }
}

let tutor = LanguageModelSession(profile: TutorProfile(model: model, effort: .xhigh))
```

Declare a profile as a type, as here. With Swift's default isolation set to the main actor, as in a new Xcode app
project, a profile built inside a function fails to compile with "sending 'profile' risks causing data races".

A request's `ContextOptions` replaces the profile's level for that request.

#### Apple's levels work too

Apple's `.light`, `.moderate` and `.deep` work with every model too. The provider module sends the nearest level the
model accepts, so `.deep` asks Claude Haiku 5.5 for `high`, and a debug build shows a
runtime warning when it has to move a level:

```swift
let quick = try await session.respond(to: "Plan dinner.", contextOptions: ContextOptions(reasoningLevel: .light))
```

#### Models picked at runtime

A model picked at runtime, from `catalogModels` or `init(catalogID:)`, has levels known only at runtime, so
`reasoningLevel(_:)` takes any level for it. Pick one from its details to send a level it accepts:

```swift
if let picked = OpenRouterModel(catalogID: "openai/gpt-5-mini"), let highest = picked.reasoningEfforts.first {
    let model = OpenRouterLanguageModel(picked, apiKey: { try await keyStore.openRouterKey() })
    let session = LanguageModelSession(model: model)
    let response = try await session.respond(
        to: "Plan a trip.",
        contextOptions: ContextOptions(reasoningLevel: model.reasoningLevel(highest))
    )
}
```

The model's reasoning arrives in the transcript as reasoning entries.
[Reasoning with OpenRouter models](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/reasoning)
says what each level becomes and how reasoning goes back on later turns.

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

### Testing and evaluation

Any model works with Apple's Evaluations framework, as the model under test, the judge or the sample generator, so one
evaluation can run against Apple's on-device model and remote ones, changing only `model:`. A scripted model makes unit
tests offline and repeatable. See
[Evaluating a feature across models](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/evaluatingacrossmodels),
[Testing with a scripted model](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/testingwithascriptedmodel),
[Judging and generating samples with OpenRouter models](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/judgingandgeneratingsamples)
and [Repeatable runs with remote models](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/repeatableruns).

Apple's own guides:

- [Evaluations](https://developer.apple.com/documentation/evaluations), the framework's documentation, with
  [Evaluating language model responses](https://developer.apple.com/documentation/evaluations/evaluating-language-model-responses)
  and [Designing specific, measurable criteria in an evaluation suite](https://developer.apple.com/documentation/evaluations/designing-evaluation-criteria).
- [Evaluating a Core AI model](https://developer.apple.com/documentation/evaluations/evaluating-a-core-ai-model), a
  sample that evaluates a custom `LanguageModel` beside Apple's default model, and
  [Book Tracker: Using Evaluations to evaluate an intelligent feature](https://developer.apple.com/documentation/evaluations/book-tracker-using-evaluations-to-evaluate-an-intelligent-feature),
  a sample with judges, synthetic data and tool-call checks.
- [Analyzing the runtime performance of your Foundation Models app](https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app),
  with the Foundation Models instrument, which records sessions of any model.
- WWDC26: [Meet the Evaluations framework](https://developer.apple.com/videos/play/wwdc2026/298/),
  [Create robust evaluations for agentic apps](https://developer.apple.com/videos/play/wwdc2026/299/),
  [Improve your prompts by hill-climbing with Evaluations](https://developer.apple.com/videos/play/wwdc2026/335/) and
  [Debug and profile agentic app experiences with Instruments](https://developer.apple.com/videos/play/wwdc2026/243/).

### Logging

Each request logs what it sends and leaves out, its retries and how it ended, never keys, prompts or answers. To log
less, set a level once:

```swift
LanguageModelsLogging.level = .error  // Only failed requests and removed models; .off logs nothing.
```

[Logging](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/logging) says
what each level logs and how to watch the messages.

## Example app

[`Example/`](Example) holds Showcase, a macOS command-line tour of the package, one command for each feature: `chat`,
`tools`, `guided`, `reasoning`, `search`, `fallbacks`, `caching`, `attachments`, `profiles`, `compare`, `catalog`
and `providers`. Each command is a short file in `Example/Showcase/Commands` that uses the package the way an app would.
Its [README](Example/README.md) says how to run it from Xcode or the terminal.

## Documentation

The [documentation](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation) is on the Swift
Package Index. It opens on `OpenRouterLanguageModels`, the OpenRouter model, its catalog and settings, and its module
switcher leads to `LanguageModels`, the model details and typed reasoning efforts every provider module shares.

For sessions, tools, guided generation and profiles, see Apple's
[Foundation Models documentation](https://developer.apple.com/documentation/foundationmodels).

## Testing

```sh
swift test
```

The test suites run offline, against stubbed HTTP responses. Live suites, which call real models through OpenRouter,
run only when `OPENROUTER_API_KEY` is set. They check that requests and answers map correctly, not how good a model's
answers are. A full live run costs a few cents.

```sh
OPENROUTER_API_KEY=… swift test --filter 'OpenRouterLanguageModelsTests\.Live'
```

A sweep of each vendor's cheapest model runs only when `LIVE_SWEEP` is set as well. The live suite of model and
provider info needs no key, and runs only when `LIVE_INFO` is set:

```sh
LIVE_INFO=1 swift test --filter LiveInfoTests
```

## Contributing

Issues and pull requests are welcome. For a larger change, such as a new provider module, open an issue first.
[CONTRIBUTING.md](CONTRIBUTING.md) says how to build and test, refresh the model catalog, and add a provider module.

## Related projects

* [Foundation Models framework utilities](https://github.com/apple/foundation-models-utilities) is Apple's package of
  extra utilities for the framework, such as custom skills, context management helpers, and a chat completions client
  that connects to a hosted model.
* [AnyLanguageModel](https://github.com/huggingface/AnyLanguageModel) reimplements the Foundation Models API, so it runs
  on earlier OS versions and Linux, and adds on-device backends such as MLX and llama.cpp.
* [ClaudeForFoundationModels](https://github.com/anthropics/ClaudeForFoundationModels) is Anthropic's native package for
  Claude models.

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE).
