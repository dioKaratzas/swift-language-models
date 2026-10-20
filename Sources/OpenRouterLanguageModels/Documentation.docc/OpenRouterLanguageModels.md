# ``OpenRouterLanguageModels``

Use any model on OpenRouter in Foundation Models sessions.

## Overview

``OpenRouterLanguageModel`` plugs an OpenRouter model into Foundation Models, so sessions, prompts, tools, guided
generation, profiles and reasoning levels work as they do with Apple's own models:

```swift
import FoundationModels
import LanguageModels
import OpenRouterLanguageModels

let model = OpenRouterLanguageModel(.anthropicClaudeSonnet4_6, apiKey: { try await keyStore.openRouterKey() })
let session = LanguageModelSession(model: model, tools: [FoodTool()], instructions: "Plan the week's meals.")
let plan = try await session.respond(to: "Something light for Monday.")
```

Every model OpenRouter lists is a static member of ``OpenRouterModel``, with its context size, parameters, input
and output kinds, reasoning levels and prices. Its effort type lists exactly the levels the model accepts, so
`.model(model, effort: .high)` on a profile fails to compile for a model without `high`.

## Topics

### Models

- ``OpenRouterLanguageModel``
- ``OpenRouterModel``
- ``OpenRouterModelID``
- <doc:Mapping>

### Model data

- ``OpenRouterParameter``
- ``OpenRouterInputModality``
- ``OpenRouterOutputModality``
- ``OpenRouterReasoning``
- ``OpenRouterPricing``

### Request settings

- ``OpenRouterRouting``
- ``OpenRouterProviderName``
- ``OpenRouterProviderSort``
- ``OpenRouterQuantization``
- ``OpenRouterOptions``
- ``OpenRouterVerbosity``
- ``OpenRouterServiceTier``
- ``OpenRouterAutoRouter``
- ``OpenRouterCacheControl``
- ``OpenRouterResponseCache``
- ``OpenRouterAppCategory``

### Server tools

- ``OpenRouterServerTool``
- ``OpenRouterWebSearchEngine``
- ``OpenRouterWebSearchMode``
- ``OpenRouterSearchContextSize``
- ``OpenRouterWebFetchEngine``

### Results and errors

- ``OpenRouterMetadataKey``
- ``OpenRouterCitation``
- ``OpenRouterError``
