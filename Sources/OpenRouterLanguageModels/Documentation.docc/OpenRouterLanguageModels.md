# ``OpenRouterLanguageModels``

@Metadata {
    @PageImage(
        purpose: icon,
        source: "swift-language-models-page-icon",
        alt: "The Swift Language Models icon."
    )
    @PageImage(
        purpose: card,
        source: "swift-language-models-card",
        alt: "The Swift Language Models icon on an indigo and magenta background."
    )
}

Use any model on OpenRouter in Foundation Models sessions.

## Overview

![The Swift Language Models icon: a network of model providers on an indigo background.](swift-language-models-icon)

``OpenRouterLanguageModel`` plugs an OpenRouter model into Foundation Models, so sessions, prompts, tools, guided
generation, profiles and reasoning levels work as they do with Apple's own models:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "session")

Every model in the catalog is a static member of ``OpenRouterModel``, with its context size, parameters, input and
output kinds and reasoning levels. Its effort type lists exactly the levels the model accepts, so
`model.reasoningLevel(_:)` offers only those levels.

What changes often, such as a model's prices and the health of each host that serves it, comes from OpenRouter when
an app asks, as <doc:ModelAndProviderInfo> shows.

Model details, typed reasoning efforts and logging live in the
[`LanguageModels` module](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels),
which this module re-exports.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Authentication>
- <doc:ChoosingAModel>
- ``OpenRouterLanguageModel``
- ``OpenRouterModel``
- ``OpenRouterAuthentication``

### Models

- ``OpenRouterModelID``
- ``OpenRouterParameter``
- ``OpenRouterInputModality``
- ``OpenRouterOutputModality``
- ``OpenRouterPricing``

### Tools, guided generation and reasoning

- <doc:ToolsAndGuidedGeneration>
- <doc:Reasoning>
- ``OpenRouterReasoning``

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
- ``FileAttachment``

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

### Testing and evaluation

- <doc:JudgingAndGeneratingSamples>
- <doc:RepeatableRuns>

### Reference

- <doc:Mapping>
