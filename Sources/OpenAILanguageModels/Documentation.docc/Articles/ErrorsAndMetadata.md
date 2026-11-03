# Errors and metadata

Handle failures, and read what OpenAI reports about each answer.

## Overview

Rate limits, oversized contexts, content filters, refusals, timeouts and images OpenAI can't use throw Foundation
Models' own `LanguageModelError`, so the same `catch` works for every model. Anything else, such as a rejected API key
or a quota that ran out, throws ``OpenAIError``, with its ``OpenAIError/status``, ``OpenAIError/code``,
``OpenAIError/errorType``, ``OpenAIError/parameter``, ``OpenAIError/requestID`` and ``OpenAIError/retryAfter``:

@Snippet(path: "swift-language-models/Snippets/OpenAIErrors", slice: "errors")

``OpenAIError/isQuotaExhausted`` is `true` whatever OpenAI's code for the limit, such as `insufficient_quota`,
`credit_balance_exhausted` or a project's spending limit. OpenAI sends it as a 429, but waiting doesn't clear it, so it
throws ``OpenAIError`` rather than `LanguageModelError.rateLimited`.

A `LanguageModelError` that a failure becomes carries the HTTP status, OpenAI's error code and OpenAI's id for the
request in its metadata, under `LanguageModelMetadataKey.status`, `LanguageModelMetadataKey.errorCode` and
`LanguageModelMetadataKey.requestID`. OpenAI's support asks for the request id. A failed connection, a timeout, a rate
limit, a server error or an unavailable gateway is retried up to twice, as the official SDKs retry them, before any data
arrives, unless OpenAI asks for a wait longer than 2 minutes or says not to retry.
<doc:Mapping#Errors> lists what each failure becomes.

### Read an answer's metadata

The entry that ends an answer carries facts about the answer: the model that answered, OpenAI's ids for the response
and the request, why the answer ended, and the service tier that served it. The answer's usage carries the input,
cached, output and reasoning tokens, and the prompt tokens written to the cache when OpenAI reports them. The facts
are stored under the bare keys of `LanguageModelMetadataKey`, which every provider module spells the same way:

@Snippet(path: "swift-language-models/Snippets/OpenAIErrors", slice: "metadata")

A text answer cut off at its token limit doesn't throw; its finish reason is `length`. A guided answer cut off there
throws `GeneratedContent.ParsingError`, and one cut off inside its tool calls throws ``OpenAIError`` with
``OpenAIError/Code/invalidResponse``, so no tool runs with partial arguments.

A request that ends in tool calls has the same facts. Foundation Models keeps no readable metadata on a tool-calls
entry, so they sit on its first call. A request that asks for several calls at once has one set of facts.

The only fact OpenAI reports that other providers don't is the `phase` of each of an answer's messages, under
``OpenAIMetadataKey/phases``, which <doc:Reasoning> describes. Saved transcripts keep the keys, so their spellings
never change.

### Add up a response's usage

Each round of tool calls is a request of its own. A response's `usage` has only its last request's tokens, and a
session's own `usage` adds up the token counts of every request, failed ones included. The entry that ends each
request carries only the prompt tokens written to the cache, when OpenAI reports them, so to count a whole response,
read the session's `usage` before and after it. The package keeps no prices, so it reports what each request counted,
not what it cost.

### Apple's guides

- [LanguageModelError](https://developer.apple.com/documentation/foundationmodels/languagemodelerror)
- [Transcripts](https://developer.apple.com/documentation/foundationmodels/transcripts)
- [Improving the safety of generative model output](https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output),
  on guardrail violations and refusals

### OpenAI's guides

- [Error codes](https://developers.openai.com/api/docs/guides/error-codes)
- [Rate limits](https://developers.openai.com/api/docs/guides/rate-limits)
- [Debugging requests](https://developers.openai.com/api/reference/overview#debugging-requests), on the `x-request-id`
  header
