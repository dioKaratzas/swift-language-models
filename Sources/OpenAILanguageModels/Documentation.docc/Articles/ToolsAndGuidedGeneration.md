# Tools and guided generation

Call the session's tools and generate `Generable` values with OpenAI models.

## Overview

Tools and guided generation are plain Foundation Models: a session takes `Tool` values, and `respond(to:generating:)`
returns a `Generable` type. This article covers what OpenAI models add: which models take them, what a request sends,
and what comes back.

### Check what a model takes

A model calls tools when it lists `tools`, which gives it `.toolCalling`, and generates `Generable` values when it lists
`structured_outputs`, which gives it `.guidedGeneration`, so OpenAI holds the answer to the schema:

```swift
print(OpenAIModel.gpt6Luna.capabilities.contains(.toolCalling))  // true
print(OpenAIModel.gpt6Luna.capabilities.contains(.guidedGeneration))  // true
print(OpenAIModel.gpt5_2Pro.capabilities.contains(.guidedGeneration))  // false: it doesn't list `structured_outputs`
```

A model that doesn't list `tools` gets no tools: the session's tools and `tool_choice` stay out of the request.

### Call tools and generate a value

A session can use tools and guided generation in the same request. The model calls tools first, the session runs them
and sends their outputs back, and the last answer is the `Generable` value:

```swift
@Generable
struct Dinner {
    @Guide(description: "The dish's name.")
    var name: String

    @Guide(description: "The minutes it takes to cook.", .range(5...120))
    var minutes: Int
}

func suggestDinner(using model: some LanguageModel) async throws -> Dinner {
    let session = LanguageModelSession(model: model, tools: [RecipeSearch()], instructions: "Suggest one dinner.")
    return try await session.respond(to: "Something with lentils.", generating: Dinner.self).content
}
```

- The session's tools go out as `function` tools, with each tool's name, description and argument schema, and with
  `strict` set to `false`.
- The calls of one answer form one tool-calls entry, so calls the model makes in parallel run as one round.
  ``OpenAIOptions/parallelToolCalls`` allows or stops parallel calls; by default OpenAI decides. It goes out only with
  the session's tools, to a model that lists `parallel_tool_calls`.
- A tool without arguments gets an empty JSON object.
- Each tool's output goes back as a `function_call_output`, matched to its call by its id. An output of text alone goes
  as one string, a line per part; one with attachments goes as parts, as <doc:Attachments> describes.
- When the model reasoned before its calls, its reasoning goes back before them, as <doc:Reasoning> describes.
- The facts OpenAI reports about a request that ends in tool calls, such as the model that answered, are on the
  tool-calls entry's first call, as <doc:ErrorsAndMetadata> describes.
- An answer cut off at its token limit inside a tool call throws ``OpenAIError`` with
  ``OpenAIError/Code/invalidResponse``, so no tool runs with partial arguments.

### Require a tool call

`toolCallingMode` becomes `tool_choice`: `auto` when tools are allowed, and `required` when the model must call one.
It goes out only with the session's tools. A required mode throws `LanguageModelError.unsupportedCapability` before
sending anything when the model doesn't list `tools`:

```swift
do {
    let response = try await session.respond(
        to: "Find a recipe with lentils.",
        options: GenerationOptions(toolCallingMode: .required)
    )
    print(response.content)
} catch LanguageModelError.unsupportedCapability(let unsupported) {
    print("The model can't be made to call a tool:", unsupported.debugDescription)
}
```

When tool calls are disallowed, the request sends no tools at all.

### How the schema is sent

- The request sends the schema as `text.format`, of type `json_schema`, with `strict` set to `true`, so OpenAI holds
  the answer to it.
- The request sends the full schema first. When OpenAI rejects one of its constraints, with a 400 whose message names
  a constraint keyword, such as `minimum`, `maxItems` or `pattern`, and says it isn't supported, permitted or allowed,
  the request goes once more with the portable schema, whose constraints move into the descriptions. In the example,
  `.range(5...120)` becomes part of the `minutes` description.
- Whichever schema the request sent, the answer is checked against the full one. A value that breaks a guide, such as
  a `minutes` of 2 in the example, throws `GeneratedContent.ParsingError`, which names the value and the guide. Its
  `underlyingError` is a `GuideViolations` that lists each value with its path, keyword and limit, so an app can clamp
  a number or cut a list short instead of asking again. A streamed response is checked once it ends, so its snapshots
  may show such a value before the stream throws.
- A guided answer cut off at its token limit throws `GeneratedContent.ParsingError`, since it would decode as a wrong
  value.
- With `includeSchemaInPrompt`, the schema also goes as text in the prompt that asked for it.

<doc:Mapping#Requests> lists each of these in full.

### Apple's guides

- [Expanding generation with tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling)
- [Generating Swift data structures with guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)
