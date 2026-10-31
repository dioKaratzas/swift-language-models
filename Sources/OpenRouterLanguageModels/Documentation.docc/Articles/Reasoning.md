# Reasoning with OpenRouter models

See which models reason, what a reasoning level becomes, and how reasoning comes back and goes out again.

## Overview

Foundation Models sets how much a model reasons with `ContextOptions.ReasoningLevel`, as
[Reasoning levels](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/reasoninglevels)
describes. An OpenRouter model's ``OpenRouterModel/reasoning`` says whether it reasons at all, and its
``OpenRouterModel/reasoningEfforts`` which levels it accepts:

@Snippet(path: "swift-language-models/Snippets/Reasoning", slice: "reasoning")

### Which models reason

``OpenRouterReasoning`` has three cases:

- ``OpenRouterReasoning/unsupported``: the model doesn't reason, and a request sends no reasoning level.
- ``OpenRouterReasoning/optional(enabledByDefault:)``: the model reasons when asked, or also by default, and a request
  can turn reasoning off.
- ``OpenRouterReasoning/mandatory``: the model always reasons, so a request can't turn reasoning off.

A model that reasons has `.reasoning` in its ``OpenRouterModel/capabilities``.

### What a level becomes

- A model's own level, from ``DetailedLanguageModel/reasoningLevel(_:)`` or
  ``FoundationModels/LanguageModelSession/DynamicProfile/model(_:effort:)``, goes out as `reasoning.effort` as it is.
  `off` goes out as `none`, OpenRouter's word for it.
- Apple's `.light`, `.moderate` and `.deep` ask for `low`, `medium` and `high`, and go out as the nearest effort the
  model accepts. DeepSeek V4 Flash accepts `xhigh`, `high` and `off`, so `.deep` and `.moderate` both go out as `high`.
  A level sent as another effort is logged, and a debug build shows a runtime warning for it.
- Only `off` turns reasoning off. A model asked to reason keeps reasoning.
- A model that reasons at a level it picks itself lists no efforts, so a level only turns reasoning on or off with
  `reasoning.enabled`, and a model that always reasons is never asked to stop.
- With fallbacks, the effort is the nearest that every model accepts. When they share none, the request only turns
  reasoning on or off.

### Read the model's reasoning

The model's reasoning arrives in the transcript as a reasoning entry, before the answer's text: from OpenRouter's
`reasoning_details` and `reasoning`, and from a `<think>` or `<thinking>` block that opens the answer's text. Only a
block at the start counts, after any whitespace, so a tag later in the answer stays text. The answer's usage counts
the reasoning tokens in `output.reasoningTokenCount`.

### Reasoning on later turns

Each request sends the transcript, and with it the reasoning of earlier answers, in the form OpenRouter needs back:

- The details go back on the answer's `assistant` message, and a block goes back at the start of its text, as the
  model wrote it.
- Reasoning goes back only to the model that wrote it. Each request tries the model first, so the reasoning of an
  answer that a fallback wrote is left out.
- Reasoning text that Anthropic or Gemini signed goes back only with its signature, since they reject it without one.
- Reasoning that another provider module wrote, in a transcript that moved between models, isn't sent.

OpenRouter's record of a server-tool call is part of the reasoning details too, as <doc:ServerTools> describes.

### OpenRouter's guides

- [Reasoning Tokens](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens)
