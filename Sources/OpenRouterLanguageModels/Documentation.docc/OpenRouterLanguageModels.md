# ``OpenRouterLanguageModels``

Use any model on OpenRouter in Foundation Models sessions.

## Overview

``OpenRouterLanguageModel`` plugs an OpenRouter model into Foundation Models, so sessions, prompts, tools, guided
generation, profiles and reasoning levels work as they do with Apple's own models:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "session")

Every model in the catalog is a static member of ``OpenRouterModel``, with its context size, parameters, input and
output kinds and reasoning levels. Its effort type lists exactly the levels the model accepts, so
`.model(model, effort: .high)` on a profile fails to compile for a model without `high`.

What changes often, such as a model's prices and the health of each host that serves it, comes from OpenRouter when
an app asks, as <doc:ModelAndProviderInfo> shows.

Model details, typed reasoning efforts and logging live in the
[`LanguageModels` module](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels).

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ChoosingAModel>
- ``OpenRouterLanguageModel``
- ``OpenRouterModel``

### Models

- ``OpenRouterModelID``
- ``OpenRouterParameter``
- ``OpenRouterInputModality``
- ``OpenRouterOutputModality``
- ``OpenRouterReasoning``
- ``OpenRouterPricing``

### Model and provider info

- <doc:ModelAndProviderInfo>
- ``OpenRouterProvider``
- ``OpenRouterCurrentDetails``

### Routing and fallbacks

- <doc:RoutingAndFallbacks>
- ``OpenRouterRouting``
- ``OpenRouterProviderName``
- ``OpenRouterProviderSort``
- ``OpenRouterQuantization``
- ``OpenRouterAutoRouter``

### Caching

- <doc:Caching>
- ``OpenRouterCacheControl``
- ``OpenRouterResponseCache``

### Server tools

- <doc:ServerTools>
- ``OpenRouterServerTool``
- ``OpenRouterCitation``
- ``OpenRouterWebSearchEngine``
- ``OpenRouterWebSearchMode``
- ``OpenRouterSearchContextSize``
- ``OpenRouterWebFetchEngine``

### Attachments

- <doc:Attachments>
- ``OpenRouterPDFEngine``

### Request settings

- ``OpenRouterOptions``
- ``OpenRouterVerbosity``
- ``OpenRouterServiceTier``
- ``OpenRouterApp``
- ``OpenRouterAppCategory``

### Results and errors

- <doc:ErrorsAndMetadata>
- ``FoundationModels/Transcript/Response/openRouter``
- ``OpenRouterResponseMetadata``
- ``OpenRouterFinishReason``
- ``FoundationModels/LanguageModelSession/Usage/openRouter``
- ``OpenRouterUsageMetadata``
- ``OpenRouterMetadataKey``
- ``OpenRouterError``

### Reference

- <doc:Mapping>
