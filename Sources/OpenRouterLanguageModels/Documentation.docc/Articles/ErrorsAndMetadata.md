# Errors and metadata

Handle failures, and read what OpenRouter reports about each answer.

## Overview

Rate limits, oversized contexts, content filters, refusals and timeouts throw Foundation Models' own
`LanguageModelError`, so the same `catch` works for every model. Anything else, such as a rejected API key or no
credits left, throws ``OpenRouterError``, with its HTTP status, code, host and retry delay:

@Snippet(path: "swift-language-models/Snippets/Errors", slice: "errors")

A `LanguageModelError` that a failure becomes carries the HTTP status, OpenRouter's error code and the host in its
metadata, under ``OpenRouterMetadataKey/status``, ``OpenRouterMetadataKey/errorCode`` and
``OpenRouterMetadataKey/provider``. A gateway failure is retried once, before any data arrives. <doc:Mapping#Errors>
lists what each failure becomes.

### Read an answer's metadata

The entry that ends an answer carries facts about the answer: the model that answered, its host, its response id, why
the answer ended, the service tier that served it, and whether the response cache served it. The answer's usage carries
what it cost and counted: its cost and, when OpenRouter reports them, the host's charge and its parts, whether the
account's own key paid the host, the prompt tokens written to the host's cache, and the server tools' calls.
``OpenRouterMetadataKey`` names the keys:

@Snippet(path: "swift-language-models/Snippets/Errors", slice: "metadata")

An answer cut off at its token limit doesn't throw; its finish reason is ``OpenRouterFinishReason/length``.

Keys of facts that every model reports, such as `model`, `provider` and `cost`, have no prefix, so code that reads
them works with any language model in this package; keys that only OpenRouter has start with `openRouter.`. OpenRouter
calls the host that serves a model its provider, so `provider` names the host.

### See how OpenRouter routed a request

With ``OpenRouterOptions/includesRouterMetadata``, the entry also reports how OpenRouter routed the request: the
strategy, the endpoints it could pick from, each attempt, the edge region, how long the host took, and the plugins that
changed the request or the answer.
