# Reasoning levels

Choose how much a model reasons, with Apple's levels or with the model's own.

## Overview

Foundation Models sets how much a model reasons with `ContextOptions.ReasoningLevel`: on a profile, with
`reasoningLevel(_:)`, or for one request, in its `ContextOptions`. A provider sends the level as the nearest effort the
model accepts. `.light`, `.moderate` and `.deep` ask for `low`, `medium` and `high`, and a level the model doesn't
accept moves to the nearest one it does, the lower one on a tie. A model asked to reason keeps reasoning, so only
``FoundationModels/ContextOptions/ReasoningLevel/off`` turns reasoning off.

### Use the model's own levels

Each model's details name an effort type, ``ModelDetails/Effort``, that lists exactly the levels the model accepts,
highest first. Set the model on a Dynamic Profile with
``FoundationModels/LanguageModelSession/DynamicProfile/model(_:effort:)``, and a level the model doesn't accept fails
to compile:

@Snippet(path: "swift-language-models/Snippets/Effort", slice: "profile")

Declare the profile as a type, as above. With Swift's default isolation set to the main actor, as in a new Xcode app
project, a profile built in a function and passed to `LanguageModelSession(profile:)` fails to compile with "sending
'profile' risks causing data races".

The effort becomes the profile's reasoning level, so it follows the same precedence as `reasoningLevel(_:)`: a level
set closer to the profile, or in a request's `ContextOptions`, takes its place:

@Snippet(path: "swift-language-models/Snippets/Effort", slice: "request")

``FoundationModels/ContextOptions/ReasoningLevel`` also gains a level for each effort word that providers use, such as
``FoundationModels/ContextOptions/ReasoningLevel/xhigh`` and ``FoundationModels/ContextOptions/ReasoningLevel/max``,
for a request that asks for one without a profile.

### Pick levels at runtime

A model whose levels are known only at runtime, such as one a person picks from a list, has
`ContextOptions.ReasoningLevel` as its effort type, so it takes any level. Its details still list the levels it
accepts:

@Snippet(path: "swift-language-models/Snippets/Effort", slice: "runtime")

### Effort types

The effort types are generated from the providers' model lists, one for each set of levels that some models accept,
and grouped under ``Efforts``. Each set is a `String` enum that's `CaseIterable` and `Codable`, so an app can list a
model's levels or store the one a person picked. A model that doesn't reason, or reasons at a level it picks itself,
has ``Efforts/Unsupported``, which has no levels.

A type of your own can be an effort type too: conform an enum that lists a set of levels to ``ModelEffort``.
