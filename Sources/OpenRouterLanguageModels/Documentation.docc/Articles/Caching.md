# Caching

Pay less for prompts a host has seen, and nothing for requests OpenRouter has answered before.

## Overview

Two caches cut what a session costs. A host's prompt cache keeps the start of a prompt it has read, so a later request
that starts the same way reads that part at a fraction of the input price. Each request sends the whole transcript, so
every turn of a session starts the way the turn before it did. OpenRouter's response cache keeps whole answers, so a
request that repeats an earlier one gets the earlier answer back at no cost.

Prices below are multiples of the model's input price, and ``OpenRouterPricing/cacheRead``,
``OpenRouterPricing/cacheWrite`` and ``OpenRouterPricing/cacheWriteOneHour`` hold each model's own.

### Hosts that cache on their own

Most hosts cache long prompts without being asked:

| Host | Writes | Reads |
|---|---|---|
| OpenAI | Free before GPT-5.6; 1.25× from GPT-5.6 | 0.25× or 0.5×, by model |
| DeepSeek | 1× | 0.1× |
| xAI, for Grok | Free | 0.25× |
| Moonshot AI | Free | 0.25× |
| Groq, for Kimi K2 | Free | 0.5× |
| Z.AI | Free for a limited time | About 0.2×, as each model lists |
| Google, for Gemini 2.5 and later | Free, with no storage cost | 0.25× |

OpenAI caches prompts of 1,024 tokens or more. Gemini's minimum depends on the model: 1,024 tokens for Gemini 2.5 Flash
and 4,096 for Gemini 2.5 Pro.

### Hosts that cache only marked prompts

| Host | Writes | Reads | Lifetime |
|---|---|---|---|
| Anthropic, for Claude | 1.25× for 5 minutes, 2× for an hour | 0.1×, and less on some newer models | 5 minutes or an hour |
| Alibaba, for the Qwen models that list a cache write price | 1.25× | 0.1× | 5 minutes |

Claude's minimum is 512 to 4,096 tokens, depending on the model. A shorter prompt isn't cached, even when marked, and
costs what an unmarked one does. Each read of a Claude cache restarts its lifetime at no extra cost.

A mark on a Gemini request switches it from implicit caching to explicit caching: a write costs the input price plus
five minutes of storage, a read 0.25×, and the cache lasts five minutes from its write, however often it's read.

Five-minute caching pays for itself on the first reuse: a prompt written and then read costs 1.25× + 0.1× = 1.35× its
input price, against 2× for sending it twice uncached. An hour's caching costs 2× to write, so it pays only from the
second reuse: 2.2× against 3×.

### What requests mark

``OpenRouterLanguageModel/cacheControl`` is ``OpenRouterCacheControl/automatic`` unless the model is created with
another. It marks a request for five minutes only when every model the request may reach, fallbacks included, caches
only marked prompts: Claude, as `anthropic/…` or an alias such as `~anthropic/claude-haiku-latest`, and the Qwen
models whose ``OpenRouterPricing/cacheWrite`` is set. A request that may reach any other model goes unmarked, so hosts
that cache on their own keep doing so, and a Gemini fallback never switches to explicit caching.

A marked request carries a top-level `cache_control`, which Claude's hosts read as a mark at the end of the prompt
that moves forward as the conversation grows, and a marker on the last part of the last instructions.

The prompt cache needs no code, and the answer's usage says what it did: the tokens read from the cache, and in
``OpenRouterUsageMetadata/cacheWriteTokenCount``, the tokens written to it:

@Snippet(path: "swift-language-models/Snippets/Caching", slice: "usage")

To keep a cache for an hour, pass a lifetime:

@Snippet(path: "swift-language-models/Snippets/Caching", slice: "oneHour")

``OpenRouterCacheControl/always`` and ``OpenRouterCacheControl/always(timeToLive:)`` mark every request, whatever
models it may reach, such as for Claude with another vendor's fallback, which `automatic` leaves unmarked, or for
Gemini's explicit caching:

@Snippet(path: "swift-language-models/Snippets/Caching", slice: "always")

A `nil` cache control sends no marks:

@Snippet(path: "swift-language-models/Snippets/Caching", slice: "unmarked")

### Stay on the host that cached the prompt

Each host keeps its own cache, and a model can have several hosts, such as Claude on Anthropic, Amazon Bedrock and
Google Vertex. OpenRouter sends a conversation's later requests for the same model to the host that served it, so they
find its cache. Each request names its session by the id of the transcript's first prompt, so this starts with the
session's first answer.

- OpenRouter does this only when the host's cache reads cost less than its prompts.
- It forgets the host after 10 minutes without a request, and moves on to the next-best host when that one is
  unavailable.
- A routing with an ``OpenRouterRouting/order`` turns it off, so the order wins over the cache.

### Answer repeated requests from the response cache

With ``OpenRouterLanguageModel/responseCache`` set, OpenRouter keeps each answer for a while, and answers a request that
repeats one, with the same API key and body, with the kept answer, at no cost and without reaching a host:

@Snippet(path: "swift-language-models/Snippets/ResponseCache", slice: "cache")

A hit repeats the kept answer whatever the temperature, sampling mode or seed, so it's the same answer every time
until it expires or ``OpenRouterResponseCache/refreshes`` replaces it:

@Snippet(path: "swift-language-models/Snippets/ResponseCache", slice: "refresh")

Each request sends the transcript so far, so requests repeat one another when their sessions went the same way, such
as new sessions with the same instructions and prompt. ``OpenRouterResponseCache`` says what else a hit needs.
