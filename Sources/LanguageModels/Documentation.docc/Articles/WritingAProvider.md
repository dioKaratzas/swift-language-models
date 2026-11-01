# Writing a provider module

Connect another service's models to Foundation Models.

## Overview

A provider module connects one service's models to Foundation Models. Its model conforms to
``DetailedLanguageModel``, and its request executor to ``DetailedLanguageModelRequestExecutor``. The model's executor,
which Foundation Models' `LanguageModelExecutor` describes, is always this module's ``DetailedLanguageModelExecutor``
of that request executor, as Apple's
[Running a Core AI model in a Foundation Models session](https://developer.apple.com/documentation/foundationmodels/running-a-core-ai-model-in-a-foundation-models-session)
shows for a model of your own. A provider module re-exports this module with `@_exported public import LanguageModels`,
so a file that imports the provider module can use the core's types too.

This package's own provider modules are added as
[CONTRIBUTING.md](https://github.com/dioKaratzas/swift-language-models/blob/main/CONTRIBUTING.md) describes.

### Describe the models

The model's details type conforms to ``ModelDetails``. Its `id` has a type of the provider module's own that conforms
to ``ProviderVocabulary``, and so does every other word from the service's API, such as a parameter name. Each of
those types declares only `rawValue` and `init(rawValue:)`: string literals and `description` come from the protocol.

The details' ``ModelDetails/removalDate`` is the day the service stopped listing the model, as the module's catalog
records it, or `nil` for a model the catalog doesn't record as removed. The model's
``DetailedLanguageModelBase/fallbacks`` are the models the service tries when it fails, or none.

The details' ``ModelDetails/Effort`` lists the levels a model accepts: ``Efforts/Of`` with a type for each model
that conforms to ``ModelEffortList``, which this package's generator writes with a static member for each level, an
enum of your own that conforms to ``ModelEffort``, or `ContextOptions.ReasoningLevel` for a model known only at
runtime. A module outside this package lists a model's levels with an enum of its own.
``FoundationModels/LanguageModelSession/DynamicProfile/model(_:effort:)`` takes an effort of that type, so a profile
takes only the levels the model accepts.

### Send requests

The model's `RequestExecutor` conforms to ``DetailedLanguageModelRequestExecutor``. Foundation Models creates the
model's executor, a ``DetailedLanguageModelExecutor``, from the model's `executorConfiguration`, and calls it for each
answer. The executor logs an error and, in a debug build, shows a runtime warning for each removed model the request
may reach, then calls the request executor's ``DetailedLanguageModelRequestExecutor/execute(_:model:streamingInto:)``,
which sends the request and returns the answer's response text in a ``DetailedLanguageModelAnswer``, or empty text
when the answer ends in tool calls. For a request
with a schema, the executor checks that text against the schema's guides, since a host may drop or ignore a
constraint, and throws `GeneratedContent.ParsingError` when a value breaks one. A module can't replace the executor,
so every module gets the same checks. Keep secrets, such as the API key closure, on the model rather than in the
configuration.

- Send a reasoning level as the nearest effort the model accepts, as <doc:ReasoningLevels> describes, and leave out
  every setting the model doesn't list.
- Report `.guidedGeneration` only for a model whose service holds the answer to the schema, such as with strict
  structured outputs. JSON mode alone often returns JSON that doesn't match the schema, which then throws instead of
  answering.
- Return the response text exactly as the response entry got it, without reasoning, so the executor checks what
  Foundation Models decodes.
- Throw `LanguageModelError` wherever it has a case, so the same `catch` works for every model, and an error type of
  the module's own for the rest. Foundation Models 2.1.14, in Xcode 27.2, drops the `metadata` argument of
  `LanguageModelError.ContextSizeExceeded`'s initializer, so set `metadata` after creating it.
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
