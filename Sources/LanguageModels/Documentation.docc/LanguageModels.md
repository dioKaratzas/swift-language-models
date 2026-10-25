# ``LanguageModels``

Describe provider models and choose their reasoning level in Foundation Models sessions.

## Overview

A provider's model conforms to ``DetailedLanguageModel``, so it carries ``ModelDetails``: its name, capabilities,
context size, the reasoning levels it accepts and the kinds of data it takes as attachments and generates. Foundation
Models reads the capabilities and data kinds from the details.

Each model's details name an effort type that lists the model's levels. Pass an effort of that type when you set the
model on a profile, and a level the model doesn't accept fails to compile:

```swift
import FoundationModels
import LanguageModels

let profile = LanguageModelSession.Profile { Instructions("Plan the week's meals.") }
    .model(model, effort: .high)
let session = LanguageModelSession(profile: profile)
```

The effort becomes the profile's `ContextOptions.ReasoningLevel`, so `reasoningLevel(_:)` and a request's
`ContextOptions` work as they do with any model. Models whose levels are known only at runtime take any
`ContextOptions.ReasoningLevel` as their effort.

## Logging

The package logs each request to the unified logging system, under the subsystem
`com.niosoft.swift-language-models`, with a category for each provider, such as `OpenRouter`. Each message names its
request by the first eight characters of the request's id, so the messages of requests sent at once can be told apart.

| Level | Messages |
|---|---|
| Debug | What a request sends: the model, its fallbacks and the names of the options. Which model and host answered, the finish reason, whether the response cache served the answer, the time to the first token and the whole time. A cancelled request |
| Info | What a request leaves out or changes from what the app asked for: options the models don't list, metadata past the provider's limits, a reasoning level sent as another effort, and a response cache's time to live outside its range. A retry after a gateway failure, or with a portable schema after a host rejected a constraint |
| Error | A failed request: the error it became, such as `LanguageModelError.rateLimited`, with the HTTP status, error code and host it came from |

The system decides what it keeps, as it does for Apple's frameworks: debug messages only while a tool such as Xcode
or Console shows them, info messages in memory, and errors on disk, up to a limit. Messages are formatted only when
someone reads them, so logging costs little.

The package never logs API keys, prompts, answers, tool arguments or outputs, or attachments. Model ids, host names,
parameter names, HTTP statuses, error codes and timings are public. A host's error message, which may quote the
request, and the keys of metadata left out are private, so the system redacts them.

To watch the messages, filter Xcode's console by `subsystem:com.niosoft.swift-language-models`, or stream them in
Terminal; for a simulator, run the same command after `xcrun simctl spawn booted`:

```sh
log stream --level debug --predicate 'subsystem == "com.niosoft.swift-language-models"'
```

Logging is on at every level. To log less, set ``LanguageModelsLogging/level`` once, early, from any thread:

```swift
import LanguageModels

LanguageModelsLogging.level = .error  // Only failed requests.
LanguageModelsLogging.level = .off  // Nothing.
```

In a debug build, Xcode also shows a purple runtime warning where the package works around a likely mistake: a
request that leaves out or changes something the app asked for, and a response cache's time to live outside its
range. Setting the level to `.off` silences the warnings too; any other level leaves them on. A release build never
shows them.

## Topics

### Models

- ``DetailedLanguageModel``
- ``ModelDetails``
- ``ProviderVocabulary``

### Reasoning level

- ``ModelEffort``
- ``Efforts``

### Logging

- ``LanguageModelsLogging``
