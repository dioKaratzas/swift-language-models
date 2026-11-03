# Caching

Help OpenAI's prompt cache serve the start of a prompt, and see what it read.

## Overview

OpenAI's prompt cache keeps the start of a prompt it has read, so a later request that starts the same way reads that
part from the cache. Each request sends the whole transcript, so every turn of a session starts the way the turn before
it did. The module sends no cache marks: OpenAI caches on its own.

Every part of a request is written the same way each time, in the same order, from the model and the instructions to
the transcript's earlier turns, its images and its settings, so a prompt that starts the same way is sent with the
same bytes. Apple's
[Optimizing key-value caching in language model sessions](https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions)
still applies: a transcript that keeps its start unchanged keeps the cache valid.

### Group requests with a cache key

``OpenAIOptions/cacheKey`` groups requests whose prompts start the same, so OpenAI's cache serves their shared start
more often. It goes out as `prompt_cache_key`, and it's `nil` unless the model is created with one:

- ``OpenAIOptions/CacheKey/session`` gives each session its own key: the id of its first prompt, which stays the same
  for the whole session. A request before the first prompt sends none.
- ``OpenAIOptions/CacheKey/named(_:)`` gives a key of the app's own, such as one for every session that shares the same
  long instructions.

```swift
let model = OpenAILanguageModel(
    .gpt6Luna,
    options: OpenAIOptions(cacheKey: .named("meal-planner-handbook")),
    auth: .apiKey { try await keyStore.openAIKey() }
)
```

### See what the cache did

The cache needs no code, and the answer's usage says what it did: the input tokens, and the ones read from the cache
in `input.cachedTokenCount`:

```swift
let session = LanguageModelSession(model: model, instructions: handbook)
let response = try await session.respond(to: "What's the refund policy?")

print("Input tokens:", response.usage.input.totalTokenCount)
print("Read from the cache:", response.usage.input.cachedTokenCount)
```

When OpenAI reports the prompt tokens it wrote to the cache, the usage's metadata and the entry that ends the answer
carry them under `LanguageModelMetadataKey.cacheWriteTokenCount`.

A first request reads nothing from the cache, and a cache that serves a prefix may take a moment to fill, so a request
sent right after another may still read nothing.
