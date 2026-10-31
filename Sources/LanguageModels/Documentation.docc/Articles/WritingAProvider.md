# Writing a provider module

Connect another service's models to Foundation Models.

## Overview

A provider module connects one service's models to Foundation Models. Its model conforms to
``DetailedLanguageModel``, and its executor conforms to Foundation Models' `LanguageModelExecutor`, as Apple's
[Running a Core AI model in a Foundation Models session](https://developer.apple.com/documentation/foundationmodels/running-a-core-ai-model-in-a-foundation-models-session)
shows for a model of your own. A provider module re-exports this module with `@_exported public import LanguageModels`,
so a file that imports the provider module can use the core's types too.

This package's own provider modules are added as
[CONTRIBUTING.md](https://github.com/dioKaratzas/swift-language-models/blob/main/CONTRIBUTING.md) describes.

### Describe the models

The model's details type conforms to ``ModelDetails``. Its `id` has a type of the provider module's own that conforms
to ``ProviderVocabulary``, and so does every other word from the service's API, such as a parameter name. Each of
those types declares only `rawValue` and `init(rawValue:)`: string literals and `description` come from the protocol.

The details' ``ModelDetails/Effort`` lists the levels a model accepts: one of the generated ``Efforts`` types, an enum
of your own that conforms to ``ModelEffort``, or `ContextOptions.ReasoningLevel` for a model known only at runtime.
``FoundationModels/LanguageModelSession/DynamicProfile/model(_:effort:)`` takes an effort of that type, so a profile
takes only the levels the model accepts.

### Send requests

The model's `Executor` conforms to Foundation Models' `LanguageModelExecutor`. Foundation Models creates it from the
model's `executorConfiguration` and calls it for each answer. Keep secrets, such as the API key closure, on the model
rather than in the configuration.

- Send a reasoning level as the nearest effort the model accepts, as <doc:ReasoningLevels> describes, and leave out
  every setting the model doesn't list.
- Throw `LanguageModelError` wherever it has a case, so the same `catch` works for every model, and an error type of
  the module's own for the rest.
- Follow redirects only to the same host, so credentials never reach another server.

### Report what happened

Put facts about an answer in the metadata of the entry that ends it, and what it cost and counted in its usage's
metadata. A fact that every provider module reports, such as `model`, `provider`, `responseID`, `finishReason` or
`cost`, uses the same bare key in every module. A fact only one module reports takes the module's prefix, such as
`openRouter.`, so keys never collide.

Never log API keys, prompts, answers, tool arguments or outputs, or attachments.

To test the module's behavior without a network, drive a session with a scripted model, as
<doc:TestingWithAScriptedModel> shows.

### Apple's guides

- [Running a Core AI model in a Foundation Models session](https://developer.apple.com/documentation/foundationmodels/running-a-core-ai-model-in-a-foundation-models-session)
- [LanguageModelExecutor](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutor)
- [LanguageModelExecutorGenerationChannel](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel)
