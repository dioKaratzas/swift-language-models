# Swift Language Models

[![CI](https://github.com/dioKaratzas/swift-language-models/actions/workflows/ci.yml/badge.svg)](https://github.com/dioKaratzas/swift-language-models/actions/workflows/ci.yml)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FdioKaratzas%2Fswift-language-models%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/dioKaratzas/swift-language-models)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FdioKaratzas%2Fswift-language-models%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/dioKaratzas/swift-language-models)
[![License](https://img.shields.io/badge/license-Apache_2.0-blue.svg)](LICENSE)

One Foundation Models API for cloud and local language models. Apple's `LanguageModelSession`, with its transcripts,
tools, `@Generable` guided generation, Dynamic Profiles and reasoning levels, is the one interface, and provider
modules plug other models into it, so Claude, GPT, Gemini, DeepSeek, Qwen, Llama and Mistral run through the same
session as Apple's on-device model. OpenRouter is the first provider module, and more are coming.

* [Quick start](#quick-start)
* [How it works](#how-it-works)
* [Providers](#providers)
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

Foundation Models 27 lets any type conform to its `LanguageModel` protocol. This package adds those conformances for
providers, and nothing else: your app keeps `import FoundationModels` and Apple's own sessions, transcripts, tools,
guided generation, Dynamic Profiles and `LanguageModelError`, so new framework features reach every provider without a
copy to update. Moving a session between Apple's on-device model and a remote one changes only its `model:`.

The package has two kinds of module. `LanguageModels` is the core every provider shares: `DetailedLanguageModel` and
`ModelDetails`, typed reasoning efforts, `FileAttachment` and `LanguageModelsLogging`. Each provider is a module of its
own, whose model conforms to `DetailedLanguageModel` and whose executor sends the requests, maps the provider's
errors to `LanguageModelError`, and reports usage, reasoning and tool calls in Apple's transcript. A provider module
re-exports the core, so one import is enough.

## Providers

| Provider | Module | Status |
|---|---|---|
| [OpenRouter](https://openrouter.ai) | `OpenRouterLanguageModels` | Available. 380+ models from Anthropic, OpenAI, Google, DeepSeek, Qwen, Meta, Mistral and others, in a typed catalog |
| Local models | | Coming |

Each provider is its own library product, so an app builds only the providers it imports. More provider modules,
local ones included, will follow.

## Features

- **Foundation Models native.** Sessions, transcripts, tools, guided generation, Dynamic Profiles and reasoning
  levels are Apple's own, and work the same with every provider.
- **Typed model catalog.** Every OpenRouter model is a static member of `OpenRouterModel`, such as
  `.anthropicClaudeHaiku5_5`, with its context size, output limit, parameters, data kinds and reasoning efforts;
  `catalogModels` and `init(catalogID:)` serve models picked at runtime.
- **Typed reasoning efforts.** Apple's `.light`, `.moderate` and `.deep` map to the nearest effort a model accepts, and
  a model's own effort type lists exactly its levels, so a level it doesn't take fails to compile.
- **Fallbacks and provider routing.** Models to try in order when one fails, and which hosts may serve them, by
  price, throughput, data policy, region or quantization.
- **Prompt caching.** Prompts are marked for the hosts that cache only marked prompts, such as Anthropic's, and
  OpenRouter's response cache answers a repeated request at no cost.
- **Server tools.** Web search, web fetch, the date and time, and advisor and subagent models run on OpenRouter while
  the model answers, with cited pages on the response.
- **Attachments.** Images from OS 27.0; PDFs, audio, video and text through `FileAttachment` from OS 27.2; and
  generated images back as data entries.
- **Live model details and pricing.** `providers()`, `currentDetails()` and `currentPricing()` read each host's
  prices, limits and uptime, and today's prices, from OpenRouter.
- **Response metadata.** The cost, host, model, response id and finish reason of each answer, as typed values.
- **Errors.** Rate limits, oversized contexts, content filters, refusals and timeouts throw `LanguageModelError`;
  everything else throws the provider's own error, with its status, code and retry delay.
- **Logging.** Each request logs what it sends and leaves out, its retries and how it ended, never keys, prompts or
  answers, and a debug build shows an Xcode runtime warning for a setting a model doesn't take.

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

Then add the provider's product to each target that uses it:

```swift
.product(name: "OpenRouterLanguageModels", package: "swift-language-models")
```

`import OpenRouterLanguageModels` is all a file needs besides `import FoundationModels`. It re-exports `LanguageModels`,
the core every provider shares, so typed reasoning efforts, `FileAttachment` and the model details come with it.

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

It works with every model whose `capabilities` include `.guidedGeneration`.

### Reasoning effort

Apple's reasoning levels work with every model that reasons. The provider sends `.light`, `.moderate` and `.deep` as
the nearest effort the model accepts:

```swift
let response = try await session.respond(
    to: "How many weekdays are in March 2027?",
    contextOptions: ContextOptions(reasoningLevel: .deep)
)
```

For one of the model's own efforts, set the model on a Dynamic Profile with `model(_:effort:)`. Each catalog model's
effort type lists exactly the levels that model accepts, so any other level fails to compile:

```swift
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

### Fallbacks and routing

`fallbacks:` lists models to try, in order, when the model fails for any reason, such as downtime, a rate limit or a
prompt too long for its context, and `routing` chooses which of a model's hosts OpenRouter may use:

```swift
let model = OpenRouterLanguageModel(
    .anthropicClaudeHaiku5_5,
    fallbacks: .openaiGpt5Mini, .googleGemini3_1FlashLite,
    routing: OpenRouterRouting(dataCollection: .deny, requiresZeroDataRetention: true, sort: .price),
    apiKey: { try await keyStore.openRouterKey() }
)
let response = try await LanguageModelSession(model: model).respond(to: "Plan a picnic for Saturday.")

if case .response(let answer)? = response.transcriptEntries.last, let answeredBy = answer.openRouter.model {
    print("\(answeredBy) answered.")
}
```

Any of the models may answer, so the model's capabilities, and each request, narrow to what all of them support.

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

### More

Prompt caching, the response cache, server tools and citations, generated images, today's prices and each host's
health, response metadata, errors and logging each have an article in the
[OpenRouter documentation](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels).
To log less, set a level once:

```swift
LanguageModelsLogging.level = .error  // Only failed requests; .off logs nothing.
```

## Example app

[`Example/`](Example) holds Showcase, a macOS command-line tour of the package, one command for each feature: `chat`,
`tools`, `guided`, `reasoning`, `search`, `fallbacks`, `caching`, `attachments`, `profiles`, `providers` and
`catalog`. Each command is a short file in `Example/Showcase/Commands` that uses the package the way an app would.
Its [README](Example/README.md) says how to run it from Xcode or the terminal.

## Documentation

The [documentation](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation) is on the Swift
Package Index. It opens on `OpenRouterLanguageModels`, the OpenRouter model, its catalog and settings, and its module
switcher leads to `LanguageModels`, the model details and typed reasoning efforts every provider shares.

For sessions, tools, guided generation and profiles, see Apple's
[Foundation Models documentation](https://developer.apple.com/documentation/foundationmodels).

## Testing

```sh
swift test
```

The test suites run offline, against stubbed HTTP responses. Live suites, which call real models through OpenRouter,
run only when `OPENROUTER_API_KEY` is set. A full live run costs a few cents.

```sh
OPENROUTER_API_KEY=… swift test --filter 'OpenRouterLanguageModelsTests\.Live'
```

A sweep of each vendor's cheapest model runs only when `LIVE_SWEEP` is set as well. The live suite of model and
provider info needs no key, and runs only when `LIVE_INFO` is set:

```sh
LIVE_INFO=1 swift test --filter LiveInfoTests
```

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

## Related projects

* [AnyLanguageModel](https://github.com/huggingface/AnyLanguageModel) reimplements the Foundation Models API, so it runs
  on earlier OS versions and Linux, and adds on-device backends such as MLX and llama.cpp.
* [ClaudeForFoundationModels](https://github.com/anthropics/ClaudeForFoundationModels) is Anthropic's native package for
  Claude models.

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE).
