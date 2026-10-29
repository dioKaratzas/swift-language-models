# Routing and fallbacks

Choose which hosts serve a model, and which models to try when it fails.

## Overview

OpenRouter serves most models from several hosts, such as the model's maker, Amazon Bedrock or Google Vertex, and
picks one for each request. ``OpenRouterRouting`` limits and orders the hosts it may pick, and fallbacks name other
models to try when the model fails.

OpenRouter calls these hosts providers, so the package keeps that word wherever it names one:
``OpenRouterProviderName``, ``OpenRouterRouting/allowedProviders``, ``OpenRouterError/providerName`` and the
``OpenRouterMetadataKey/provider`` key.

### Fall back to other models

Fallbacks are models that OpenRouter tries in order when the model fails, whatever the error: a prompt too long for
its context, a moderation flag, a rate limit or downtime. Catalog models of any effort type can follow the model:

@Snippet(path: "swift-language-models/Snippets/Fallbacks", slice: "fallbacks")

For models picked at runtime, set ``OpenRouterLanguageModel/fallbacks`` instead:

@Snippet(path: "swift-language-models/Snippets/Fallbacks", slice: "runtime")

Any of the models may answer, so a request asks only for what all of them support:

- ``OpenRouterLanguageModel/details`` describes the first model, but ``OpenRouterLanguageModel/capabilities``,
  `supportsDataAttachmentType(_:)` and `supportsDataEntryType(_:)` answer for the whole list. Tool calling, guided
  generation, reasoning and images work only when every model supports them, and an attachment or data kind only when
  every model takes it.
- A setting is sent only when every model lists its parameter, and the token limit is the smallest of their limits.
  Structured outputs are used only when every model takes them, otherwise JSON mode when every model takes that.
- A reasoning level becomes the nearest effort that every model accepts. When they share none, the request only turns
  reasoning on or off, and it doesn't turn reasoning off when any model always reasons.
- A schema goes in portable form, with its constraints in descriptions, when any of the models is Anthropic's.
- The routing applies to every model, so a ``OpenRouterRouting/variant`` suffixes each of their ids.
- A context that's too long is reported with the smallest context size of the models.

Reasoning goes back on later turns only to the model that wrote it. Each request tries the first model again, so the
reasoning of an answer that a fallback wrote is left out of later requests.

The answer's ``OpenRouterResponseMetadata/model`` names the model that answered, and the request is billed at that
model's price, as <doc:ChoosingAModel#What-a-request-costs> describes.

### Choose the hosts

Every routing setting left `nil` keeps OpenRouter's default. A routing can put hosts first, keep the request on them
and cap the price:

@Snippet(path: "swift-language-models/Snippets/Fallbacks", slice: "routing")

- ``OpenRouterRouting/order`` lists the hosts to try first, and ``OpenRouterRouting/allowsFallbacks`` set to `false`
  keeps the request off other hosts when those are unavailable. An order turns off OpenRouter's sticky routing, so
  requests of one session may reach a host that hasn't cached their prompt.
- ``OpenRouterRouting/allowedProviders`` and ``OpenRouterRouting/ignoredProviders`` name the only hosts to use and
  hosts never to use.
- ``OpenRouterRouting/dataCollection`` and ``OpenRouterRouting/requiresZeroDataRetention`` leave out hosts by what
  they do with prompts, and ``OpenRouterRouting/requiresDistillableText`` leaves out models whose authors don't allow
  training on their output.
- ``OpenRouterRouting/sort`` ranks hosts, such as by price or throughput, when no order is set. With fallbacks,
  ``OpenRouterRouting/sortPartition`` says whether every model's hosts are ranked together.
- ``OpenRouterRouting/maximumPrice`` and ``OpenRouterRouting/quantizations`` leave out hosts that cost too much or run
  the model at another precision, while ``OpenRouterRouting/preferredMinimumThroughput`` and
  ``OpenRouterRouting/preferredMaximumLatency`` only try slower hosts later.
- ``OpenRouterRouting/variant``, such as `nitro` or `floor`, ranks the hosts and lets a service tier compete.
- With tools, server tools or a response schema, a request asks for hosts that honor every parameter it sends, unless
  ``OpenRouterRouting/requiresParameters`` says otherwise.
