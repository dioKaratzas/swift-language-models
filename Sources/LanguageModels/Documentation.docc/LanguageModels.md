# ``LanguageModels``

Describe provider models and choose their reasoning level in Foundation Models sessions.

## Overview

A provider's model conforms to ``DetailedLanguageModel``, so it carries ``ModelDetails``: its name, capabilities,
context size, the reasoning levels it accepts and the kinds of data it takes as attachments and generates. Foundation
Models reads the capabilities and data kinds from the details. A ``ModelCatalog`` lists the models a provider offers
now.

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

## Topics

### Models

- ``DetailedLanguageModel``
- ``ModelDetails``
- ``ModelCatalog``
- ``ProviderVocabulary``

### Reasoning level

- ``ModelEffort``
- ``Efforts``
