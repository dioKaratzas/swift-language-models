# Server tools

Let OpenRouter search the web, fetch pages, tell the time and consult other models while the model answers.

## Overview

Server tools are tools that OpenRouter runs for the model while it answers: a web search, a web page fetch, the
current date and time, an advisor model to consult and a subagent model to hand tasks to. The app implements nothing;
the model calls them as it needs, and only its answer reaches the session. A web search's answer lists the pages it
cites on its response entry, as ``OpenRouterCitation`` values that `Transcript.Response.openRouterCitations` reads:

@Snippet(path: "swift-language-models/Snippets/ServerTools", slice: "search")

### Consult other models

An advisor is a model that the model asks for advice while it answers, and a subagent is a model that it hands
self-contained tasks to, with server tools of its own:

@Snippet(path: "swift-language-models/Snippets/ServerTools", slice: "models")

Each call is a request to the other model. Chat completions return neither the model's request nor the other model's
answer, so an advisor can't recall earlier consultations.

### Choose who sees the searches

The engine decides who sees what the model searches for and fetches. By default the host's own search or fetch runs
when the model's host has one, and Exa otherwise; `engine` picks another, such as
``OpenRouterWebSearchEngine/perplexity`` or OpenRouter's own fetcher, ``OpenRouterWebFetchEngine/openrouter``.

Data retention depends on the engine. With zero data retention enforced on the account, OpenRouter rejects Firecrawl,
while Exa, Parallel, Perplexity and the hosts' own search keep what they're sent under their own policies.
``OpenRouterRouting/requiresZeroDataRetention`` picks the hosts of the model, not the engines.

### Use them with the session's tools

Server tools are sent after the session's own tools, and only when the model and every fallback take tools;
otherwise a request throws `LanguageModelError.unsupportedCapability` before sending anything. They count as tools,
so a request with them asks for hosts that honor every parameter, unless ``OpenRouterRouting/requiresParameters``
says otherwise.

A tool-calling mode concerns only the session's tools: `tool_choice` goes out only with them, although a server-tool
call can meet `.required`, and `.disallowed` leaves out the server tools too.

OpenRouter's record of a server-tool call, when it sends one, is part of the answer's reasoning details, and goes back
on later turns with them unless a fallback wrote the answer.

Searches, fetches and calls to other models cost extra, as <doc:ChoosingAModel#What-a-request-costs> describes.
