# Mapping

How Foundation Models requests become OpenRouter requests, and how OpenRouter's answers come back.

## Overview

A sampling or output setting, such as `temperature`, `stop` or `verbosity`, reaches the model only when the model
lists its parameter in ``OpenRouterModel/supportedParameters``; otherwise it's left out, so a host never rejects a
request for it. The tables say which settings go out whatever the model lists, such as `service_tier` and `user`.
With ``OpenRouterLanguageModel/fallbacks``, any of the models may answer, so a setting is sent only when every one of
them lists its parameter. With tools, server tools or a response schema, the request also asks OpenRouter for hosts
that honor every parameter it sends, unless ``OpenRouterRouting/requiresParameters`` says otherwise.

A setting left out is logged, and a debug build shows a runtime warning for it. So greedy sampling reaches only models
that list `temperature` or `top_k`, and a seed only models that list `seed`; even there, neither makes a remote
model's answers repeatable, as <doc:RepeatableRuns> explains.

Data attachments and generated data need iOS 27.2 or macOS 27.2 at run time, and Xcode 27.2 at build time, since
earlier SDKs lack them. Built with an earlier Xcode, the package takes no data attachments and never asks for images.

### Requests

| Foundation Models | OpenRouter |
|---|---|
| Instructions | `system` message |
| Prompt | `user` message |
| Reasoning, response and tool calls of one answer | One `assistant` message, with `reasoning_details` and `tool_calls` |
| Tool output | `tool` message, matched by call id |
| Attachment label | A text part just before the attachment |
| Image attachment | An `image_url` part with a JPEG data URL: upright, on white, scaled down to at most 2,048 pixels on its longer side, without the image's metadata; an image at an http or https address goes as that address |
| Image data attachment, in any kind ImageIO reads | An `image_url` part, as for an image attachment |
| PDF data attachment | A `file` part with `filename`, the label ending in `.pdf` or `document.pdf`, and `file_data`, a data URL; accepted by every model, since OpenRouter reads a PDF for a model that can't |
| Audio data attachment | An `input_audio` part with `data`, bare base64, and `format`: `wav`, `mp3`, `aiff`, `aac`, `flac`, `ogg` or `m4a` |
| Video data attachment | A `video_url` part with a data URL of `video/mp4`, `video/mpeg`, `video/mov` or `video/webm` |
| Plain-text data attachment | A text part |
| A tool output with attachments | The `tool` message's content as parts |
| An image attachment when the model or a fallback doesn't take images | `LanguageModelError.unsupportedCapability` with `.vision`, before any request, as Foundation Models throws |
| A data attachment the model or a fallback doesn't take, an image file included; an attachment in the instructions | `LanguageModelError.unsupportedTranscriptContent`, before any request |
| An answer's attachments, generated data entries | Left out |
| A request without a schema when every model generates images, from iOS and macOS 27.2 | `modalities`: `["image", "text"]` |
| Response schema | `response_format` `json_schema` with `strict`; a request is refused before it's sent unless every model lists `structured_outputs` |
| Guides on a schema for a request that may reach an Anthropic model, as the model or a fallback | The portable schema: constraints that some hosts reject, such as `minimum`, `maxItems` and `pattern`, move into the description, which every host takes |
| Guides on a schema for any other request | The full schema; when the host rejects one of its constraints, with a 400 whose message names a constraint keyword and says it isn't supported, permitted or allowed, the request goes once more with the portable schema |
| `includeSchemaInPrompt` | The schema also goes in the prompt that asked for it |
| `temperature` | `temperature`, clamped to 0–2 |
| `samplingMode` `.greedy` | `temperature` 0, and `top_k` 1 |
| `samplingMode` `.random(top:seed:)` | `top_k` and `seed` |
| `samplingMode` `.random(probabilityThreshold:seed:)` | `top_p` and `seed` |
| `maximumResponseTokens` | `max_completion_tokens`, or `max_tokens`, no more than the smallest limit of the model and its fallbacks |
| `toolCallingMode` | `tool_choice`: `auto` or `required`, sent only with the session's tools; when disallowed, no tools at all, server tools included. When required, `LanguageModelError.unsupportedCapability` before any request if the model or a fallback doesn't list `tool_choice` |
| `reasoningLevel` | `reasoning.effort`, moved to the nearest level that the model and every fallback accept, but only `.off` moves to `none`; `reasoning.enabled` when there's no such level |
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
| ``OpenRouterLanguageModel/serverTools`` | `tools` entries after the session's tools, in order: `openrouter:web_search`, `openrouter:web_fetch`, `openrouter:datetime`, `openrouter:advisor` and `openrouter:subagent`, each with the `parameters` that are set, a reasoning level as the nearest effort OpenRouter lists; left out when tool calls are disallowed, and `LanguageModelError.unsupportedCapability` before any request when the model or a fallback doesn't list `tools`. They never set `tool_choice` or `parallel_tool_calls`. An advisor's or a subagent's exchange isn't returned |
| ``OpenRouterLanguageModel/fallbacks`` | `models`, the ids after `model` in the order OpenRouter tries them |
| ``OpenRouterRouting/variant`` | The variant as a suffix, such as `:nitro` or `:floor`, on `model` and on each id in `models`; everything else comes from the catalog models |
| ``OpenRouterOptions/frequencyPenalty``, ``OpenRouterOptions/presencePenalty``, ``OpenRouterOptions/repetitionPenalty``, ``OpenRouterOptions/minP``, ``OpenRouterOptions/topA``, ``OpenRouterOptions/stopSequences``, ``OpenRouterOptions/logitBias`` | `frequency_penalty`, `presence_penalty`, `repetition_penalty`, `min_p`, `top_a`, `stop`, `logit_bias`, each when the model lists it |
| ``OpenRouterOptions/verbosity`` | `verbosity`, when the model lists it |
| ``OpenRouterOptions/serviceTier`` | `service_tier` |
| ``OpenRouterOptions/endUserID`` | `user` |
| ``OpenRouterOptions/autoRouter`` | A `plugins` entry: `auto-router` for `openrouter/auto` and `auto-beta-router` for `openrouter/auto-beta`, as the model or a fallback, with `allowed_models`, `excluded_models` and `cost_tier`; other models leave it out |
| ``OpenRouterOptions/minimumCodingScore`` | A `pareto-router` `plugins` entry with `min_coding_score`, for `openrouter/pareto-code` only, as the model or a fallback |
| ``OpenRouterLanguageModel/cacheControl`` | When the request is marked, `cache_control`, and the same marker on the last part of the last instructions; ``OpenRouterCacheControl/automatic`` marks a request only when every model it may reach is Claude or has ``OpenRouterModel/cachesOnlyMarkedPrompts`` set |
| ``OpenRouterLanguageModel/responseCache`` | `X-OpenRouter-Cache: true` and `X-OpenRouter-Cache-TTL`, the time to live in whole seconds from 1 to 86,400; `X-OpenRouter-Cache-Clear: true` when it refreshes. A hit repeats the kept answer whatever the sampling |
| ``OpenRouterOptions/pdfEngine`` | A `file-parser` `plugins` entry with `pdf.engine`, only for a request with a PDF; without it, OpenRouter's default: the model's own reading, or Mistral's OCR. With `native`, only models that read PDFs take them |
| ``OpenRouterOptions/includesRouterMetadata`` | `X-OpenRouter-Metadata: enabled` header |
| ``OpenRouterApp/name`` | `X-OpenRouter-Title` header |
| ``OpenRouterApp/url`` | `HTTP-Referer` header |
| ``OpenRouterApp/categories`` | `X-OpenRouter-Categories` header, the first two categories, comma-separated |
| ``OpenRouterApp/isHidden`` | `X-OpenRouter-App-Visibility: hidden` header |
| The package and the app | `User-Agent` header: `swift-language-models ({bundleID}/{appVersion}; Swift/{swiftVersion}; {os}/{osVersion})`, such as `swift-language-models (com.example.Planner/2.3; Swift/6.4; iOS/27.0.1)`; outside an app bundle, without the app |
| ``OpenRouterLanguageModel/baseURL`` | Where requests go: `chat/completions` under it, instead of `https://openrouter.ai/api/v1/` |
| ``OpenRouterLanguageModel/idleTimeout`` | The request's `timeoutInterval` |

### Answers

| OpenRouter | Foundation Models |
|---|---|
| `delta.content` | Response text |
| `delta.reasoning_details`, `delta.reasoning`, and a `<think>` or `<thinking>` block that opens `delta.content` | Reasoning text, in the order it arrives; the details go in the reasoning entry's signature and are sent back on later turns, unless a fallback wrote them. A block leaves the answer with its tags and the whitespace around it, and goes back as the model wrote it, at the start of the `assistant` message's `content`, unless a fallback wrote it; its text isn't sent again as `reasoning`. Only a block at the start counts, after any whitespace, so a tag later in the answer stays text; a block the answer never closes is reasoning to the end |
| `delta.tool_calls` | One tool-calls entry per answer, so parallel calls make one round |
| `delta.images` | One data entry per image, of the kind its data URL names, from iOS and macOS 27.2; an image at a web address is left out |
| `delta.annotations` of type `url_citation` | ``OpenRouterCitation`` values on the response entry, under ``OpenRouterMetadataKey/citations``, once each; they aren't sent back |
| `reasoning.server_tool_call` in `delta.reasoning_details` | OpenRouter's record of a server tool's call and result, kept with the other details and sent back on later turns; it never becomes a tool call |
| `usage` | Usage: prompt, cached, output and reasoning tokens; in its metadata, the `cost`, `cache_write_tokens` and `is_byok` |
| `usage.cost_details` | Usage metadata: `upstream_inference_cost`, `upstream_inference_prompt_cost`, `upstream_inference_completions_cost` and `server_tool_cost`, under ``OpenRouterMetadataKey`` |
| `usage.server_tool_use_details` | Usage metadata: `tool_calls_requested`, `tool_calls_executed` and `web_search_requests` as counts |
| `model`, `provider`, `id`, `finish_reason`, `service_tier` | Metadata of the entry that ends the answer, under ``OpenRouterMetadataKey``; `model` also goes on the reasoning entry |
| `X-OpenRouter-Cache-Status`, `X-OpenRouter-Cache-Age`, `X-OpenRouter-Cache-Source-Id` headers | Metadata of the entry that ends the answer: whether the response cache served it, how many seconds it had kept it, and the response id it kept |
| `openrouter_metadata` on the last chunk | Metadata of the entry that ends the answer: `strategy`, `attempt`, `attempts`, `endpoints.available`, `region`, `generation_time` in seconds, and each `pipeline` stage's `type`, `name` and `summary` |
| `finish_reason: length` | An answer cut short at its token limit, which ends without an error; one cut short inside its tool calls throws ``OpenRouterError`` with `invalid_response` instead, so no tool runs with partial arguments |

### Metadata keys

``OpenRouterMetadataKey`` names each key. A shared key has no prefix, and every language model in this package spells
it the same way; a key that only OpenRouter has starts with `openRouter.`. Saved transcripts keep the keys.
``OpenRouterResponseMetadata`` and ``OpenRouterUsageMetadata`` read the keys of a response entry and a usage as typed
properties, with amounts as `Decimal` values and times as `Duration` values.

| OpenRouter | Key |
|---|---|
| `model` | `model`, on the entry that ends the answer and on its reasoning entry |
| `provider`, the host that served the answer | `provider` |
| `id` | `responseID` |
| `finish_reason` | `finishReason` |
| `service_tier` | `serviceTier` |
| `delta.annotations` of type `url_citation` | `citations`, on the response entry |
| `usage.cost` | `cost`, in the usage's metadata |
| `usage.prompt_tokens_details.cache_write_tokens` | `cacheWriteTokenCount`, in the usage's metadata |
| `usage.is_byok` | `openRouter.isBYOK`, in the usage's metadata |
| `usage.cost_details`: `upstream_inference_cost`, `upstream_inference_prompt_cost`, `upstream_inference_completions_cost`, `server_tool_cost` | `openRouter.upstreamInferenceCost`, `openRouter.upstreamInferencePromptCost`, `openRouter.upstreamInferenceCompletionCost`, `openRouter.serverToolCost`, in the usage's metadata |
| `usage.server_tool_use_details`: `tool_calls_requested`, `tool_calls_executed`, `web_search_requests` | `openRouter.requestedServerToolCallCount`, `openRouter.executedServerToolCallCount`, `openRouter.webSearchCount`, in the usage's metadata |
| `X-OpenRouter-Cache-Status`, `X-OpenRouter-Cache-Age`, `X-OpenRouter-Cache-Source-Id` headers | `openRouter.responseCacheHit`, `openRouter.responseCacheAge`, `openRouter.responseCacheSourceID` |
| `openrouter_metadata`: `strategy`, `attempt`, `attempts`, `endpoints.available`, `pipeline`, `region`, `generation_time` | `openRouter.routingStrategy`, `openRouter.routingAttempt`, `openRouter.routingAttempts`, `openRouter.routingEndpoints`, `openRouter.routingPipeline`, `openRouter.region`, `openRouter.generationTime` |
| A failure's HTTP status, error code and host | `status`, `openRouter.errorCode` and `provider`, in the metadata of the `LanguageModelError` it becomes |

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
`payment_required` for a 402. An error in the stream arrives after HTTP 200, so it takes its status and code from its
own `code`: a number is the status, text such as `server_error` is the code, and without either the code is `server`.
Its host is the one its metadata names, or else the chunk's `provider`.

A 502, 503, 504 or 529 is retried once, before any data arrives. A 400 that rejects a constraint of the response
schema is sent once more with the portable schema.

### Model info

The calls of <doc:ModelAndProviderInfo> read OpenRouter's lists with `GET`, and fail as a request does.

| Swift | OpenRouter |
|---|---|
| ``OpenRouterModel/providers(apiKey:session:baseURL:)`` | `models/{id}/endpoints` under the base URL, each of `data.endpoints` an ``OpenRouterProvider`` |
| ``OpenRouterModel/currentDetails(apiKey:session:baseURL:)``, ``OpenRouterModel/currentPricing(apiKey:session:baseURL:)`` | `model/{id}` under the base URL, `data` as ``OpenRouterCurrentDetails`` |
| An API key, when one is given | `Authorization: Bearer` header; none without a key |
| ``OpenRouterProvider/name``, ``OpenRouterProvider/tag``, ``OpenRouterProvider/modelID`` | `provider_name`, `tag`, `model_id` |
| ``OpenRouterProvider/serviceTier``, ``OpenRouterProvider/quantization``, ``OpenRouterProvider/status`` | `service_tier`, `quantization`, `status` |
| ``OpenRouterProvider/contextSize``, ``OpenRouterProvider/maximumOutputTokens``, ``OpenRouterProvider/maximumPromptTokens`` | `context_length`, `max_completion_tokens`, `max_prompt_tokens` |
| ``OpenRouterProvider/uptimeLast5Minutes``, ``OpenRouterProvider/uptimeLast30Minutes``, ``OpenRouterProvider/uptimeLastDay`` | `uptime_last_5m`, `uptime_last_30m`, `uptime_last_1d`, as percentages |
| ``OpenRouterProvider/latencyLast30Minutes`` | `latency_last_30m`, its `p50`, `p75`, `p90` and `p99` read as milliseconds |
| ``OpenRouterProvider/throughputLast30Minutes`` | `throughput_last_30m`, in tokens per second |
| ``OpenRouterProvider/discount`` | `pricing.discount` |
| ``OpenRouterCurrentDetails/maximumOutputTokens``, ``OpenRouterCurrentDetails/isModerated`` | `top_provider.max_completion_tokens`, `top_provider.is_moderated` |
| ``OpenRouterCurrentDetails/aliasTarget`` | `alias_target.slug` |
| ``OpenRouterCurrentDetails/expirationDate`` | `expiration_date`, at midnight UTC |
| ``OpenRouterPricing`` | `pricing`: `prompt`, `completion`, `input_cache_read`, `input_cache_write`, `input_cache_write_1h`, `internal_reasoning`, `audio`, `image`, `request` and `web_search`, each decimal text in US dollars; `nil` when `prompt` or `completion` is missing or negative, as for a router |
| ``OpenRouterPricing/Override`` | Each of `pricing.overrides`: `min_prompt_tokens` as the prompt length to exceed, `utc_days` as the weekdays, and `utc_start` and `utc_end`, `HHMM` clock numbers, as the ``OpenRouterPricing/TimeWindow``; an override whose window isn't a time of day, or that changes none of the prices above, is left out |

### Apple's guides

- [GenerationOptions](https://developer.apple.com/documentation/foundationmodels/generationoptions) and
  [ContextOptions](https://developer.apple.com/documentation/foundationmodels/contextoptions)
- [Managing the context window](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window),
  since the package turns off OpenRouter's context compression

### OpenRouter's guides

- [Parameters](https://openrouter.ai/docs/api_reference/parameters)
- [Message Transforms](https://openrouter.ai/docs/guides/features/message-transforms), for context compression
- [Service Tiers](https://openrouter.ai/docs/guides/features/service-tiers)
- [User Tracking](https://openrouter.ai/docs/cookbook/administration/user-tracking), for ``OpenRouterOptions/endUserID``
