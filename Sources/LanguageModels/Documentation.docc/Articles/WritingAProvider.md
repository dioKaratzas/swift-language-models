# Adding a provider

Add a module that brings another provider's models to Foundation Models.

## Overview

A provider is a module of this package named `<Vendor>LanguageModels`, whose `<Vendor>LanguageModel` conforms to
``DetailedLanguageModel``. Adding the vendor's name to `providers` in `Package.swift` creates the module, its library
product, and a test target with a `Fixtures` folder. The module depends on `LanguageModels` and nothing else, and
re-exports it with `@_exported public import LanguageModels`, so a file that imports the provider's module can use the
core's types and members too.

### Describe the models

The provider's details type conforms to ``ModelDetails``. Its `id` has a type of the provider's own that conforms to
``ProviderVocabulary``, and so does every other word from the provider's API, such as a parameter name. Each of those
types declares only `init(rawValue:)`: string literals and `description` come from the protocol.

The details' ``ModelDetails/Effort`` lists the levels a model accepts: one of the generated ``Efforts`` types for a
catalog model, and `ContextOptions.ReasoningLevel` for a model known only at runtime.
``FoundationModels/LanguageModelSession/DynamicProfile/model(_:effort:)`` takes an effort of that type, so a profile's
level is checked when it compiles.

### Generate the catalog

A provider whose models come from a list keeps a snapshot of it in `Catalogs/`, which the package's generator turns
into a static member for each model and into the effort types the models share. To refresh every provider's
snapshot and the generated sources, run:

```sh
swift package plugin --allow-network-connections all:443 --allow-writing-to-package-directory generate-model-catalog
```

The snapshots in `Catalogs/` and the `Generated/` sources are generated, so don't edit them by hand.

### Send requests

The model's `Executor` conforms to Foundation Models' `LanguageModelExecutor`. Foundation Models creates it from the
model's `executorConfiguration` and calls it for each answer. Keep secrets, such as the API key closure, on the model
rather than in the configuration.

- Send a reasoning level as the nearest effort the model accepts, as <doc:ReasoningLevels> describes, and leave out
  every setting the model doesn't list.
- Throw `LanguageModelError` wherever it has a case, so the same `catch` works for every model, and an error type of
  the provider's own for the rest.
- Follow redirects only to the same host, so credentials never reach another server, and send the package's
  `User-Agent`.

### Report and log

Put facts about an answer in the metadata of the entry that ends it, and what it cost and counted in its usage's
metadata. A fact that every provider reports, such as `model`, `provider`, `responseID`, `finishReason` or `cost`,
uses the same bare key in every provider. A fact only one provider reports takes the provider's prefix, such as
`openRouter.`, so keys never collide.

Log to the package's subsystem, `com.niosoft.swift-language-models`, under a category named after the provider, at
the levels the app's ``LanguageModelsLogging/level`` lets through. Never log API keys, prompts, answers, tool
arguments or outputs, or attachments. Where the provider works around a likely mistake, such as a setting the model
doesn't take, log it at the info level and show a runtime warning in a debug build.
