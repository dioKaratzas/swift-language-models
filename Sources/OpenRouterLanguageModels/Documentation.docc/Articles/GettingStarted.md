# Getting started

Create a model, give it an API key, and name the app to OpenRouter.

## Overview

``OpenRouterLanguageModel`` takes a model from the catalog and a closure that returns the API key. A session uses it
as it uses Apple's on-device model:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "session")

This module alone covers its own types, including ids and other words written as string literals, such as
`"anthropic/claude-haiku-5.5"`. A file that uses typed efforts, such as `.model(_:effort:)`, imports `LanguageModels`
too.

### Keep the key out of the app

The closure is called for every request, and the key is never stored. Never ship an OpenRouter key inside an app,
where anyone can extract it. Instead:

- Let the person enter their own key, keep it in the Keychain, and return it from the closure. A Keychain read
  blocks, so do it away from the main actor.
- During development, read it from an environment variable.
- In production, send requests through your own server, and return a short-lived token for that server.

During development, the closure reads the environment:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "environment")

In production, ``OpenRouterLanguageModel/baseURL`` points at your server, which adds the key and forwards the request
to OpenRouter:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "proxy")

Requests then go to `chat/completions` under the base URL, with the closure's token as the bearer token, and follow
redirects only to the same host, so the token never reaches another one. An error the closure throws ends the
request and passes through as it is, unless it's a `URLError`, which maps as a failed connection's does.

### Name the app

``OpenRouterApp`` names the app in each request's headers, which credits its usage in OpenRouter's rankings and app
marketplace:

@Snippet(path: "swift-language-models/Snippets/QuickStart", slice: "attribution")

### Send requests your own way

``OpenRouterLanguageModel/session`` sends each request, `.shared` unless the model is created with a session of your
own, such as one with a proxy. ``OpenRouterLanguageModel/idleTimeout`` limits the wait for the next data, not the
whole answer.

The package logs what each request sends and leaves out, its retries, which model and host answered, and how it ended,
without keys, prompts or answers. The
[`LanguageModels` documentation](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels)
says how to watch the messages and how to log less.
