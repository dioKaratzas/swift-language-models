# Mapping

How Foundation Models requests become OpenRouter requests, and how OpenRouter's answers come back.

## Overview

A setting reaches the model only when the model lists its parameter in ``OpenRouterModel/supportedParameters``;
otherwise it's left out, so a host never rejects a request for it. With ``OpenRouterLanguageModel/fallbacks``, any
of the models may answer, so a setting is sent only when every one of them lists its parameter. With tools, server
tools or a response schema, the request also asks OpenRouter for hosts that honor every parameter it sends, unless
``OpenRouterRouting/requiresParameters`` says otherwise.

### Requests

| Foundation Models | OpenRouter |
|---|---|
| Instructions | `system` message |
| Prompt | `user` message |
| Reasoning, response and tool calls of one answer | One `assistant` message, with `reasoning_details` and `tool_calls` |
| Tool output | `tool` message, matched by call id |
| Image and data attachments, data entries | Not yet supported; they throw `LanguageModelError.unsupportedTranscriptContent` |
| Response schema | `response_format` `json_schema` with `strict` when every model lists `structured_outputs`; otherwise `json_object` and the schema in the prompt |
| Guides on a schema for a request that may reach an Anthropic model, as the model or a fallback | Constraints Anthropic's structured outputs reject, such as `minimum`, `maxItems` and `pattern`, move into the description |
| `includeSchemaInPrompt` | The schema also goes in the prompt that asked for it |
| `temperature` | `temperature`, clamped to 0–2 |
| `samplingMode` `.greedy` | `temperature` 0, and `top_k` 1 |
| `samplingMode` `.random(top:seed:)` | `top_k` and `seed` |
| `samplingMode` `.random(probabilityThreshold:seed:)` | `top_p` and `seed` |
| `maximumResponseTokens` | `max_completion_tokens`, or `max_tokens`, no more than the smallest limit of the model and its fallbacks |
| `toolCallingMode` | `tool_choice`: `auto` or `required`, sent only with the session's tools; when disallowed, no tools at all, server tools included. When required, `LanguageModelError.unsupportedCapability` before any request if the model or a fallback doesn't list `tool_choice` |
| `reasoningLevel` | `reasoning.effort`, moved to the nearest level that the model and every fallback accept; `reasoning.enabled` when there's no such level |
| Request metadata | `metadata`, string values within OpenRouter's limits |
| The transcript's first prompt | `session_id`, so requests of one session reach the host that cached their prompt; the `X-Session-Id` header instead while the response cache is on, since the cache compares the whole body |
| The whole transcript | `plugins` with `context-compression` turned off, so OpenRouter never drops the middle of a transcript that doesn't fit |

### OpenRouter settings

| Swift | OpenRouter |
|---|---|
| ``OpenRouterRouting/order``, ``OpenRouterRouting/allowedProviders``, ``OpenRouterRouting/ignoredProviders`` | `provider.order`, `provider.only`, `provider.ignore` |
| ``OpenRouterRouting/allowsFallbacks`` | `provider.allow_fallbacks` |
| ``OpenRouterRouting/requiresParameters`` | `provider.require_parameters`, `true` when the request has tools, server tools or a response schema and it's `nil` |
| ``OpenRouterRouting/dataCollection`` | `provider.data_collection` |
| ``OpenRouterRouting/requiresZeroDataRetention`` | `provider.zdr` |
| ``OpenRouterRouting/requiresDistillableText`` | `provider.enforce_distillable_text` |
| ``OpenRouterRouting/sort`` | `provider.sort`, as the ranking's name |
| ``OpenRouterRouting/sortPartition`` | `provider.sort` as an object of `by`, the ranking, and `partition`: `model` or `none` |
| ``OpenRouterRouting/quantizations`` | `provider.quantizations` |
| ``OpenRouterRouting/maximumPrice`` | `provider.max_price`, each price a decimal string in US dollars |
| ``OpenRouterRouting/preferredMinimumThroughput`` | `provider.preferred_min_throughput` in tokens per second: one number when only `p50` is set, otherwise an object of `p50`, `p75`, `p90` and `p99` |
| ``OpenRouterRouting/preferredMaximumLatency`` | `provider.preferred_max_latency` in seconds, in the same forms |
| ``OpenRouterLanguageModel/serverTools`` | `tools` entries after the session's tools, in order: `openrouter:web_search`, `openrouter:web_fetch`, `openrouter:datetime`, `openrouter:advisor` and `openrouter:subagent`, each with the `parameters` that are set, a reasoning level as the nearest effort OpenRouter lists; left out when tool calls are disallowed, and `LanguageModelError.unsupportedCapability` before any request when the model or a fallback doesn't list `tools`. They never set `tool_choice` or `parallel_tool_calls`. Searches and fetches cost extra, and each engine keeps what it's sent under its own policy; an advisor or a subagent is billed at its model's price, and its exchange isn't returned |
| ``OpenRouterLanguageModel/fallbacks`` | `models`, the ids after `model` in the order OpenRouter tries them; a `:free` model that falls back to a paid one is billed at the paid price |
| ``OpenRouterRouting/variant`` | A `:nitro` or `:floor` suffix on `model` and on each id in `models`; everything else comes from the catalog models |
| ``OpenRouterOptions/frequencyPenalty``, ``OpenRouterOptions/presencePenalty``, ``OpenRouterOptions/repetitionPenalty``, ``OpenRouterOptions/minP``, ``OpenRouterOptions/topA``, ``OpenRouterOptions/stopSequences``, ``OpenRouterOptions/logitBias`` | `frequency_penalty`, `presence_penalty`, `repetition_penalty`, `min_p`, `top_a`, `stop`, `logit_bias`, each when the model lists it |
| ``OpenRouterOptions/verbosity`` | `verbosity`, when the model lists it |
| ``OpenRouterOptions/serviceTier`` | `service_tier` |
| ``OpenRouterOptions/endUserID`` | `user` |
| ``OpenRouterOptions/autoRouter`` | A `plugins` entry: `auto-router` for `openrouter/auto` and `auto-beta-router` for `openrouter/auto-beta`, as the model or a fallback, with `allowed_models`, `excluded_models` and `cost_tier`; other models leave it out |
| ``OpenRouterOptions/minimumCodingScore`` | A `pareto-router` `plugins` entry with `min_coding_score`, for `openrouter/pareto-code` only, as the model or a fallback |
| ``OpenRouterLanguageModel/cacheControl`` | `cache_control`, and a marker at the end of the instructions |
| ``OpenRouterLanguageModel/responseCache`` | `X-OpenRouter-Cache: true` and `X-OpenRouter-Cache-TTL`, the time to live in whole seconds from 1 to 86,400; `X-OpenRouter-Cache-Clear: true` when it refreshes. A hit repeats the kept answer whatever the sampling |
| ``OpenRouterOptions/includesRouterMetadata`` | `X-OpenRouter-Metadata: enabled` header |
| `appName` | `X-OpenRouter-Title` header |
| `appURL` | `HTTP-Referer` header |
| `appCategories` | `X-OpenRouter-Categories` header, the first two categories, comma-separated |
| `hidesApp` | `X-OpenRouter-App-Visibility: hidden` header |

### Answers

| OpenRouter | Foundation Models |
|---|---|
| `delta.content` | Response text |
| `delta.reasoning_details`, `delta.reasoning` | Reasoning text; the details go in the reasoning entry's signature and are sent back on later turns, unless a fallback wrote them |
| `delta.tool_calls` | One tool-calls entry per answer, so parallel calls make one round |
| `delta.annotations` of type `url_citation` | ``OpenRouterCitation`` values on the response entry, under ``OpenRouterMetadataKey/citations``, once each; they aren't sent back |
| `reasoning.server_tool_call` in `delta.reasoning_details` | OpenRouter's record of a server tool's call and result, kept with the other details and sent back on later turns; it never becomes a tool call |
| `usage` | Usage: prompt, cached, output and reasoning tokens; in its metadata, the `cost`, `cache_write_tokens` and `is_byok` |
| `usage.cost_details` | Usage metadata: `upstream_inference_cost`, `upstream_inference_prompt_cost`, `upstream_inference_completions_cost` and `server_tool_cost`, under ``OpenRouterMetadataKey`` |
| `usage.server_tool_use_details` | Usage metadata: `tool_calls_requested`, `tool_calls_executed` and `web_search_requests` as counts |
| `model`, `provider`, `id`, `finish_reason`, `service_tier` | Metadata of the entry that ends the answer, under ``OpenRouterMetadataKey``; `model` also goes on the reasoning entry |
| `X-OpenRouter-Cache-Status`, `X-OpenRouter-Cache-Age`, `X-OpenRouter-Cache-Source-Id` headers | Metadata of the entry that ends the answer: whether the response cache served it, how many seconds it had kept it, and the generation id it kept |
| `openrouter_metadata` on the last chunk | Metadata of the entry that ends the answer: `strategy`, `attempt`, `attempts`, `endpoints.available`, `region`, `generation_time` in seconds, and each `pipeline` stage's `type`, `name` and `summary` |
| `finish_reason: length` | An answer cut short at its token limit, which ends without an error |

### Errors

| OpenRouter | Thrown |
|---|---|
| `context_length_exceeded`, `token_limit_exceeded`, a 400 whose message mentions the context | `LanguageModelError.contextSizeExceeded` |
| 429, `rate_limit_exceeded`, a 402 for too many requests in flight | `LanguageModelError.rateLimited`, with the reset date |
| `content_policy_violation`, `finish_reason: content_filter`, a moderation 403 | `LanguageModelError.guardrailViolation` |
| `refusal`, `delta.refusal` | `LanguageModelError.refusal` |
| 408, 524, `timeout`, a timed-out connection | `LanguageModelError.timeout` |
| Anything else | ``OpenRouterError``, with its status, code, host and retry delay |

An error without `error_type` takes its code from the HTTP status, such as `authentication` for a 401 or
`payment_required` for a 402.

A 502, 503, 504 or 529 is retried once, before any data arrives.
