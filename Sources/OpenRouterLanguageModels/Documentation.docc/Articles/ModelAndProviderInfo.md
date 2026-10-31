# Model and provider info

Read a model's providers and what OpenRouter lists for it now, such as today's prices.

## Overview

The catalog holds what changes rarely about a model, such as its context size and parameters. What changes often comes
from OpenRouter when an app asks: each provider that serves the model, such as Google Vertex or Amazon Bedrock, with its
prices, limits and recent health, and the model's current prices.

The calls belong to a model: ``OpenRouterModel/providers(auth:session:)``,
``OpenRouterModel/currentDetails(auth:session:)`` and ``OpenRouterModel/currentPricing(auth:session:)``.
They need no API key, and take an optional ``OpenRouterAuthentication`` and URL session. On
``OpenRouterLanguageModel``, ``OpenRouterLanguageModel/providers()``, ``OpenRouterLanguageModel/currentDetails()`` and
``OpenRouterLanguageModel/currentPricing()`` read them for the model's ``OpenRouterLanguageModel/details`` with the
model's own authentication and session, so a proxied model's calls go to its server.

### List a model's providers

Each ``OpenRouterProvider`` is one endpoint of a provider: the provider's ``OpenRouterProvider/name``, and the
``OpenRouterProvider/tag`` that sets the endpoint apart, such as `google-vertex/europe` for Google's European region.
A provider can serve a model at several endpoints, in different regions, service tiers or precisions, so it can appear
more than once. Each endpoint has its own context size, output limit, prices, discount, request parameters and recent
uptime, and ``OpenRouterProvider/supportsImplicitCaching`` says whether it caches prompts without marks:

@Snippet(path: "swift-language-models/Snippets/ModelInfo", slice: "providers")

OpenRouter reports each endpoint's latency to the first token and its throughput, at the 50th, 75th, 90th and 99th
percentiles of the last 30 minutes, only to a call with a key. Without one,
``OpenRouterProvider/latencyLast30Minutes`` and ``OpenRouterProvider/throughputLast30Minutes`` are `nil`.

An alias, such as `~anthropic/claude-haiku-latest`, has no endpoints of its own; ``OpenRouterCurrentDetails/aliasTarget``
names the model whose endpoints serve it.

### Route to the providers you pick

``OpenRouterRouting/order`` takes an endpoint's tag, so a list of providers turns into a routing preference, such as
for the providers in one region:

@Snippet(path: "swift-language-models/Snippets/ModelInfo", slice: "route")

With ``OpenRouterRouting/allowsFallbacks`` turned off, a request goes to no other provider when the listed ones
are unavailable. <doc:RoutingAndFallbacks> describes the other routing settings.

### Read today's prices

The catalog keeps no prices, since OpenRouter changes them often.
``OpenRouterModel/currentDetails(auth:session:)`` reads what OpenRouter lists for a model now: its
prices, context size, output limit, request parameters, whether its first-ranked provider moderates content, and the
day OpenRouter retires it. ``OpenRouterModel/currentPricing(auth:session:)`` reads only the prices, as
``OpenRouterPricing``, whose ``OpenRouterPricing/prices(forPromptTokens:at:)`` applies the overrides for long prompts
and off-peak hours:

@Snippet(path: "swift-language-models/Snippets/ModelInfo", slice: "pricing")

The prices include the prompt cache's: ``OpenRouterPricing/cacheRead`` for a prompt token read from the cache, and
``OpenRouterPricing/cacheWrite`` and ``OpenRouterPricing/cacheWriteOneHour`` for one written to it, when writing costs
extra. <doc:Caching> says which hosts cache on their own and which need marks. ``OpenRouterPricing/webSearch`` is the
price of one search that the model or its host runs, and an ``OpenRouterPricing/Override`` applies while its
``OpenRouterPricing/Override/Condition`` holds.

A router, such as `openrouter/auto`, has no prices of its own, since the model it picks sets them, so its pricing is
`nil`. Either way, the answer's usage reports what a request actually cost, in ``OpenRouterUsageMetadata/cost``.

### Caching and failures

Each answer is kept in memory for a minute, by its URL and the authentication headers it was read with, so calling
these often, such as from each row of a list, doesn't fetch them again. The cache keeps a digest of the headers, never
the headers themselves, and never keeps a failure.

A call fails as a session's request does: a model OpenRouter doesn't list throws ``OpenRouterError`` with
``OpenRouterError/Code/notFound``, a rate limit throws `LanguageModelError.rateLimited`, and a gateway failure is
retried once. A call sends the headers of its ``OpenRouterAuthentication``, none without one, and follows a redirect
only to the same host.
