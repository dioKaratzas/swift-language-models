# Getting started

Create a model, give it an API key, and name the app to OpenRouter.

## Overview

``OpenRouterLanguageModel`` takes a model from the catalog and a closure that returns the API key. A session uses it
as it uses Apple's on-device model:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "session")

This module is all a file needs besides `FoundationModels`, and `Foundation` for types such as `URL`. It re-exports
`LanguageModels`, so typed efforts such as ``FoundationModels/LanguageModelSession/DynamicProfile/model(_:effort:)``,
``FileAttachment`` and the model details come with it, as do ids and other words written as string literals, such as
`"anthropic/claude-haiku-5.5"`.

Sessions, streaming, tools, guided generation and profiles work as Apple's
[Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
and [LanguageModelSession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession) describe.

### Keep the key out of the app

The closure is called for every request, and the key is never stored. Never ship an OpenRouter key inside an app,
where anyone can extract it. Instead:

- Let the person enter their own key, keep it in the Keychain, and return it from the closure. A Keychain read
  blocks, so do it away from the main actor.
- During development, read it from an environment variable, set in a scheme you leave unshared, so the key stays out
  of git.
- In production, send requests through your own server, and return a short-lived token for that server.

The examples call `keyStore.openRouterKey()`, which stands for the app's own Keychain wrapper. During development, the
closure reads the environment:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "environment")

In production, ``OpenRouterLanguageModel/baseURL`` points at your server, which adds the key and forwards the request
to OpenRouter:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "proxy")

Requests then go to `chat/completions` under the base URL, with the closure's token as the bearer token, and follow
redirects only to the same host, so the token never reaches another one. An error the closure throws ends the
request and passes through as it is, unless it's a `URLError`, which maps as a failed connection's does.

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
