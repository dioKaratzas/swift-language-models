# ``LanguageModels``

Describe provider modules' models and choose their reasoning level in Foundation Models sessions.

## Overview

Each provider module plugs one service's models into Foundation Models:

| Service | Module |
|---|---|
| [OpenRouter](https://openrouter.ai) | [`OpenRouterLanguageModels`](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels) |

This module holds what the provider modules share. A provider module's model conforms to ``DetailedLanguageModel``,
so it carries ``ModelDetails``: its name, capabilities, context size, the reasoning levels it accepts and the kinds of
data it takes as attachments and generates. Foundation Models reads the capabilities and data kinds from the details.
From OS 27.2, ``FileAttachment`` attaches a file, such as a PDF, to a prompt.

Each model's details name an effort type that lists the model's levels. Ask the model for one of them with
``DetailedLanguageModel/reasoningLevel(_:)``, and a level the model doesn't accept fails to compile:

@Snippet(path: "swift-language-models/Snippets/Effort", slice: "modelLevel")

``FoundationModels/LanguageModelSession/DynamicProfile/model(_:effort:)`` sets a level for a whole session the same
way, and Apple's `.light`, `.moderate` and `.deep` still work with every model, as <doc:ReasoningLevels> describes.

The package logs each request to the unified logging system, never with API keys, prompts or answers, as
<doc:Logging> describes.

## Topics

### Essentials

- <doc:ReasoningLevels>
- <doc:ReadingModelDetails>

### Models

- ``DetailedLanguageModel``
- ``ModelDetails``
- ``ProviderVocabulary``

### Reasoning level

- ``DetailedLanguageModel/reasoningLevel(_:)``
- ``FoundationModels/LanguageModelSession/DynamicProfile/model(_:effort:)``
- ``ModelEffort``
- ``Efforts``
- ``FoundationModels/ContextOptions/ReasoningLevel``

### Attachments

- ``FileAttachment``

### Logging

- <doc:Logging>
- ``LanguageModelsLogging``

### Testing and evaluation

- <doc:EvaluatingAcrossModels>
- <doc:TestingWithAScriptedModel>

### Provider modules

- <doc:WritingAProvider>
