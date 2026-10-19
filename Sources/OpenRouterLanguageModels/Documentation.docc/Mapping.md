# Mapping

How Foundation Models requests become OpenRouter requests, and how OpenRouter's answers come back.

## Overview

A setting reaches the model only when the model lists its parameter in ``OpenRouterModel/supportedParameters``;
otherwise it's left out, so a host never rejects a request for it. With tools or a response schema, the request
also asks OpenRouter for hosts that honor every parameter it sends, unless ``OpenRouterRouting/requiresParameters``
says otherwise.

### Requests

| Foundation Models | OpenRouter |
|---|---|
| Instructions | `system` message |
| Prompt | `user` message |
| Reasoning, response and tool calls of one answer | One `assistant` message, with `reasoning_details` and `tool_calls` |
| Tool output | `tool` message, matched by call id |
| Image and data attachments, data entries | Not yet supported; they throw `LanguageModelError.unsupportedTranscriptContent` |
| Response schema | `response_format` `json_schema` with `strict` when the model lists `structured_outputs`; otherwise `json_object` and the schema in the prompt |
| `includeSchemaInPrompt` | The schema also goes in the prompt that asked for it |
| `temperature` | `temperature`, clamped to 0–2 |
| `samplingMode` `.greedy` | `temperature` 0, and `top_k` 1 |
| `samplingMode` `.random(top:seed:)` | `top_k` and `seed` |
| `samplingMode` `.random(probabilityThreshold:seed:)` | `top_p` and `seed` |
| `maximumResponseTokens` | `max_completion_tokens`, or `max_tokens`, no more than the model's own limit |
| `toolCallingMode` | `tool_choice`: `auto`, `required`, or no tools at all when disallowed |
| `reasoningLevel` | `reasoning.effort`, moved to the nearest level the model accepts; `reasoning.enabled` for a model whose level can't be chosen |
| Request metadata | `metadata`, string values within OpenRouter's limits |
| The transcript's first prompt | `session_id`, so requests of one session reach the host that cached their prompt |

### Answers

| OpenRouter | Foundation Models |
|---|---|
| `delta.content` | Response text |
| `delta.reasoning_details`, `delta.reasoning` | Reasoning text; the details go in the reasoning entry's signature and are sent back on later turns |
| `delta.tool_calls` | One tool-calls entry per answer, so parallel calls make one round |
| `usage` | Usage: prompt, cached, output and reasoning tokens; the cost in its metadata |
| `model`, `provider`, `id` | Metadata of the entry that ends the answer, under ``OpenRouterMetadataKey`` |

### Errors

| OpenRouter | Thrown |
|---|---|
| `context_length_exceeded`, `token_limit_exceeded` | `LanguageModelError.contextSizeExceeded` |
| 429, `rate_limit_exceeded`, a 402 for too many requests in flight | `LanguageModelError.rateLimited`, with the reset date |
| `content_policy_violation`, `finish_reason: content_filter`, a moderation 403 | `LanguageModelError.guardrailViolation` |
| `refusal`, `delta.refusal` | `LanguageModelError.refusal` |
| 408, 524, `timeout`, a timed-out connection | `LanguageModelError.timeout` |
| Anything else | ``OpenRouterError``, with its status, code, host and retry delay |

A 502, 503, 504 or 529 is retried once, before any data arrives.
