# Getting started

Create a model, say how its requests authenticate, and name the app to OpenRouter.

## Overview

``OpenRouterLanguageModel`` takes a model from the catalog and an ``OpenRouterAuthentication``, such as an API key
that a closure returns. A session uses it as it uses Apple's on-device model:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "session")

This module is all a file needs besides `FoundationModels`, and `Foundation` for types such as `URL`. It re-exports
`LanguageModels`, so typed efforts and ``FoundationModels/LanguageModelSession/DynamicProfile/model(_:effort:)``,
``FileAttachment`` and the model details come with it, as do ids and other words written as string literals, such as
`"anthropic/claude-haiku-5.5"`.

Sessions, streaming, tools, guided generation and profiles work as Apple's
[Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
and [LanguageModelSession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession) describe.

### Keep the key out of the app

``OpenRouterAuthentication/apiKey(_:)`` reads an API key for every request and never stores it. It suits
development, or a key each person brings and keeps in the Keychain. A Keychain read blocks, so do it away from the
main actor. A bundled key is extractable from a shipping app, so use one only during development:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "apiKey")

The other examples call `keyStore.openRouterKey()`, which stands for the app's own Keychain wrapper.

To ship without a key, ``OpenRouterAuthentication/proxied(baseURL:headers:)`` sends requests to your own server,
which adds the key and forwards them to OpenRouter. The headers let the server authorize the caller:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "proxy")

Requests then go to the same paths under the server's URL, such as `chat/completions`, and follow redirects only to
the same host, so the headers never reach another one. The headers are read for every request, so a token can
refresh, and the package's own headers, such as `Content-Type`, take precedence over one of the same name. Model info
calls, such as ``OpenRouterLanguageModel/providers()``, go to the server too. An error that the key or the headers
throw ends the request and passes through as it is, unless it's a `URLError`, which maps as a failed connection's
does.

### Name the app

``OpenRouterApp`` names the app in each request's headers, which credits its usage in OpenRouter's rankings and app
marketplace. OpenRouter credits an app only when its ``OpenRouterApp/url`` is set; the name alone changes nothing:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "attribution")

### Send requests your own way

``OpenRouterLanguageModel/session`` sends each request, `.shared` unless the model is created with a session of your
own, such as one with a proxy. ``OpenRouterLanguageModel/idleTimeout`` limits the wait for the next data, not the
whole answer.

The package logs what each request sends and leaves out, its retries, which model and host answered, and how it ended,
without keys, prompts or answers.
[Logging](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/logging) says
how to watch the messages and how to log less.

### Next steps

- <doc:ChoosingAModel>: the catalog, models picked at runtime, and what a request costs.
- <doc:RoutingAndFallbacks>: the hosts that serve a model, and models to try when it fails.
- <doc:Caching>: paying less for prompts a host has seen.
- <doc:ErrorsAndMetadata>: the errors a request throws, and what OpenRouter reports about each answer.

### OpenRouter's guides

- [Authentication](https://openrouter.ai/docs/api_reference/authentication)
- [App Attribution](https://openrouter.ai/docs/app-attribution)
