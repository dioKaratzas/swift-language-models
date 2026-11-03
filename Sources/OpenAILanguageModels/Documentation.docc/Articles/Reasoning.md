# Reasoning with OpenAI models

See which models reason, what a reasoning level becomes, and how reasoning comes back and goes out again.

## Overview

Foundation Models sets how much a model reasons with `ContextOptions.ReasoningLevel`, as
[Reasoning levels](https://swiftpackageindex.com/ironsparrows/swift-language-models/documentation/languagemodels/reasoninglevels)
describes. An OpenAI model's ``OpenAIModel/reasoning`` says whether it reasons at all, and its
``OpenAIModel/reasoningEfforts`` which levels it accepts:

@Snippet(path: "swift-language-models/Snippets/OpenAIReasoning", slice: "level")

### Which models reason

``OpenAIModel/reasoning`` is one of these `ModelReasoning` values:

- `unsupported`: the model doesn't reason, such as GPT-4.1, and a request sends no `reasoning`.
- `onByDefault`: the model reasons unless a request turns reasoning off, which it can when the model accepts `none`,
  such as GPT-6 Luna and GPT-5.5.
- `mandatory`: the model always reasons, since it doesn't accept `none`, such as GPT-6 Astra and GPT-5.5 Pro.

A model that reasons has `.reasoning` in its ``OpenAIModel/capabilities``, and the effort it uses when a request
doesn't set one in ``OpenAIModel/defaultReasoningEffort``.

### What a level becomes

- A model's own level, from ``DetailedLanguageModel/reasoningLevel(_:)`` or
  ``FoundationModels/LanguageModelSession/DynamicProfile/model(_:effort:)``, goes out as `reasoning.effort` as it is.
  `off` goes out as `none`, OpenAI's word for it.
- Apple's `.light`, `.moderate` and `.deep` ask for `low`, `medium` and `high`, and go out as the nearest effort the
  model accepts, the lower one on a tie. GPT-5 Pro accepts only `high`, so `.light`, `.moderate` and `.deep` all go out
  as `high`. A level sent as another effort is logged, and a debug build shows a runtime warning for it.
- Only `off` turns reasoning off. A model asked to reason keeps reasoning. A model that always reasons gets its lowest
  effort for `off` instead, such as `low` for GPT-6 Astra and `minimal` for GPT-5.
- A request that sets no level leaves `reasoning.effort` out, so the model uses its default effort.
- A model that doesn't reason gets no `reasoning`, whatever the level.

### Sampling while a model reasons

A model that reasons takes `temperature` and `top_p` only while its effort is `none`. A request that sets another
level leaves them out, even when the model lists them, as GPT-5.4 does, and so does any request to a model that always
reasons, such as GPT-5 nano. A request that sets no level sends them to a model that can stop reasoning, as the
official SDKs do, since only OpenAI knows the model's default effort; OpenAI rejects them when that default isn't
`none`. Each setting left out is logged, and a debug build shows a runtime warning for it.

### Instructions

The instructions go out as a `developer` message to a model that reasons, and as a `system` message to one that
doesn't.

### Read the model's reasoning

The model's reasoning arrives in the transcript as a reasoning entry, before the answer's text. Reasoning that arrives
after the answer's text starts, as between a `commentary` message and the final answer, isn't shown, but its
`reasoning` items still go back on later turns. The entry's text is the summary
of its reasoning that the model writes, when ``OpenAIOptions/reasoningSummary`` asks for one, or the model's reasoning
text, when the model sends it. Each part of a summary starts after a blank line. The answer's usage counts the reasoning
tokens in `output.reasoningTokenCount`.

``OpenAIOptions/reasoningSummary`` has no default: without one, the request asks for no summary, and the reasoning entry
has no text, but still carries the reasoning, encrypted, so it goes back on later turns.
``OpenAIOptions/ReasoningSummary/auto`` asks for the most detailed summary the model writes, and
``OpenAIOptions/ReasoningSummary/concise`` and ``OpenAIOptions/ReasoningSummary/detailed`` for a short and a detailed
one. It goes out as `reasoning.summary`:

@Snippet(path: "swift-language-models/Snippets/OpenAIReasoning", slice: "summary")

### Reasoning on later turns

Every request to a model that reasons asks for its reasoning encrypted, with `include` set to
`reasoning.encrypted_content`. The answer's `reasoning` items, as OpenAI sent them, become the reasoning entry's
signature. Each request sends the transcript, and with it the reasoning of earlier answers:

- An answer's `reasoning` items go back before its messages and function calls, as they came.
- They go back only to the model that wrote them, or to the model it's a dated snapshot of, since encrypted reasoning
  suits only that model. The reasoning entry names the model that answered, such as `gpt-5-nano-2025-08-07`, so its
  reasoning goes back to `gpt-5-nano` too, and not to another model the session moves to.
- An answer with neither text nor tool calls, such as one cut off while it reasoned, sends no reasoning back.
- Reasoning that another provider module wrote, in a transcript that moved between models, isn't sent.

### Store responses or not

``OpenAIOptions/storage`` says whether OpenAI keeps each response, as `store`:

- ``OpenAIOptions/Storage/automatic`` leaves `store` out, so OpenAI's default applies, which keeps responses.
- ``OpenAIOptions/Storage/stored`` sends `store: true`.
- ``OpenAIOptions/Storage/notStored`` sends `store: false`. A `reasoning` item that carries no encrypted reasoning is
  left out of the request, since OpenAI can't look it up by its id.

The package sends the whole transcript, and every reasoning item goes back encrypted, so later turns work the same
whether or not OpenAI keeps the response. A session that moves from stored to not stored responses keeps answering.

### Message phases

A model can write an answer as several messages, each with a `phase`, such as `commentary` or `final_answer`. The
answer's text joins them, and the entry that ends the answer keeps the `phase` of each message, with the length of its
text, under ``OpenAIMetadataKey/phases``: a list of structures with a `phase` and a `length`. On later turns, each
message goes back as an `assistant` message of its own, with its `phase`, as OpenAI asks. When the lengths don't add up
to the answer's text, as when the text changed, the whole text goes back as one message with the last phase.

A guided answer decodes only its first message with no phase or the `final_answer` phase, as the official SDKs parse
it. The text of its other messages, such as a `commentary` preamble, stays out of the answer's text, and its structure
in ``OpenAIMetadataKey/phases`` keeps the text under `heldText` instead of a length, so it goes back in its place.

### OpenAI's guides

- [Reasoning models](https://developers.openai.com/api/docs/guides/reasoning), on efforts, summaries and encrypted
  reasoning
- [Conversation state](https://developers.openai.com/api/docs/guides/conversation-state), on `store` and message phases
