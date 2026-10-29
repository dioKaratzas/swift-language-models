# Choosing a model

Pick a model from the typed catalog or at runtime, and see what it supports and what its requests cost.

## Overview

Each model OpenRouter listed when the catalog was generated is a static member of ``OpenRouterModel``, with its
context size, parameters, input and output kinds, reasoning levels and prices:

@Snippet(path: "swift-language-models/Snippets/Catalog", slice: "catalog")

A catalog model's effort type lists exactly the levels it accepts, so `.model(model, effort: .high)` on a profile fails
to compile for a model without `high`.

### Pick a model at runtime

For a model picked at runtime, such as from a list people choose from, ``OpenRouterModel/catalogModels`` lists every
model and ``OpenRouterModel/init(catalogID:)`` finds one by its id:

@Snippet(path: "swift-language-models/Snippets/Catalog", slice: "picker")

Both give models whose efforts are in their open form, `ContextOptions.ReasoningLevel`, so models with different effort
types fit in one list; ``OpenRouterModel/init(_:)`` turns a catalog model into that form. A model that isn't in the
catalog yet takes its details from
``OpenRouterModel/init(id:displayName:releaseDate:aliasTarget:knowledgeCutoff:expirationDate:contextSize:maximumOutputTokens:inputModalities:outputModalities:supportedParameters:reasoning:reasoningEfforts:defaultReasoningEffort:pricing:)``.

### Aliases and routers

An alias, such as `~anthropic/claude-haiku-latest`, follows a vendor's newest model, and ``OpenRouterModel/aliasTarget``
names the model it points to now. A router, such as `openrouter/auto`, picks a model for each request;
``OpenRouterOptions/autoRouter`` and ``OpenRouterOptions/minimumCodingScore`` steer the routers that take them. Either
way, the answer's ``OpenRouterMetadataKey/model`` names the model that answered.

### What a model supports

``OpenRouterModel/capabilities`` come from what the model lists: tool calling from `tools`, guided generation from
`structured_outputs` or `response_format`, reasoning from ``OpenRouterModel/reasoning``, and vision from image input.

A request sends only the settings the model lists in ``OpenRouterModel/supportedParameters``, so a host never rejects
one, and a debug build shows a runtime warning in Xcode for each setting left out. Required tool calls are the
exception: only `tool_choice` makes a model call a tool, so with `toolCallingMode` set to `.required`, a request throws
`LanguageModelError.unsupportedCapability` before sending anything when the model or a fallback doesn't list it, as
Amazon's Nova models don't. <doc:Mapping> lists what each setting becomes.

### What a request costs

OpenRouter bills each request from the account's credits, at the price of the model that answered, which the answer's
``OpenRouterMetadataKey/model`` names. ``OpenRouterModel/pricing`` holds a model's prices, and
``OpenRouterPricing/prices(forPromptTokens:at:)`` applies its long-prompt and off-peak rates. What else a request
costs:

- **Fallbacks.** When a fallback answers, the request is billed at the fallback's price. That holds for a `:free` model
  too, so list only `:free` models to keep requests free.
- **The transcript.** Each request sends the whole transcript, so earlier prompts and attachments are billed as input
  again with every later request of the session. They're the same bytes each time, so a host that caches prompts bills
  the repeat at its cached price; <doc:Caching> says what each host charges.
- **Generated data.** Images a model generates, and any attachment on an answer, stay in the transcript but aren't
  sent back, so they aren't billed again.
- **PDFs.** OpenRouter reads a PDF for a model that can't, with Mistral's OCR at a price per page, unless
  ``OpenRouterOptions/pdfEngine`` picks another engine, such as the free ``OpenRouterPDFEngine/cloudflareAI``.
- **Server tools.** Web searches and fetches cost extra, on top of the model's tokens, at the engine's price.
  ``OpenRouterWebSearchEngine`` and ``OpenRouterWebFetchEngine`` say what each engine charges. An advisor or a subagent
  is a request to another model, at that model's price. The date and time are free.
- **Variants.** ``OpenRouterRouting/variant`` can bill a request at the rate of the service tier that serves it.
- **The response cache.** An answer that ``OpenRouterResponseCache`` serves costs nothing.

The answer's usage reports what it cost, under ``OpenRouterMetadataKey/cost``; <doc:ErrorsAndMetadata> shows how to
read it.
