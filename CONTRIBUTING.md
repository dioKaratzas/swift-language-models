# Contributing

Ask questions and share ideas in [Discussions](https://github.com/dioKaratzas/swift-language-models/discussions),
and report bugs in [Issues](https://github.com/dioKaratzas/swift-language-models/issues). Pull requests are
welcome. For a larger change, such as a new provider module, open an issue first.

## Build and test

Before a pull request, run `swift build` and `swift test`, and format the code with swift-format, which reads
`.swift-format`. The README's [Testing](README.md#testing) section says how to run the live suites.

## Refresh the model catalog

The files in `Catalogs/` and the `Generated/` sources are generated, so don't edit them by hand. To refresh them from
the providers' model lists, run:

```sh
swift package plugin --allow-network-connections all:443 --allow-writing-to-package-directory generate-model-catalog
```

The Model catalog workflow does the same for every provider at once, and runs `ModelCatalogGenerator diff` to classify
the changes. It keeps one pull request, `catalog/update`, with a changelog and a `release:` label for the release the
changes need:

- `major` when a generated member is deleted, which only a hand edit to a snapshot does. The pull request also gets
  `needs-review` and waits for a maintainer.
- `patch` for any other change to a snapshot: a member added, deprecated or made current again, a model that gains or
  stops accepting effort levels, or a model's limits or parameters.
- No label when only the shape of a provider's API changed.

A model, word or effort level a provider stops listing keeps its member, marked deprecated, so code that names it
still compiles, with a warning. `minor` is for the package's own features.

The workflow builds with warnings as errors. So when a provider retires or stops listing a model that a snippet or
test names, the build fails and the workflow opens no pull request: name another model there, update the README if it
names the model too, and run the workflow again.

Any pull request but a major one merges once CI passes, and its label releases it.
[Model catalogs](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/modelcatalogs)
describes the same rules for the package's users.

## Add a provider module

A provider module is named `<Vendor>LanguageModels`, and its `<Vendor>LanguageModel` conforms to
`DetailedLanguageModel`. The article
[Writing a provider module](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/writingaprovider)
describes the model, its request executor and what it reports. In this repository:

- Add `provider("<Vendor>", uses: [...])` to `providers` in `Package.swift`, naming the API format targets the module
  builds on, such as `provider("OpenRouter", uses: ["ChatCompletionsAPI"])`. That declares the module, its library
  product, and a test target that copies `Tests/<Vendor>LanguageModelsTests/Fixtures`, which you create. The module
  depends on `LanguageModels` and on those formats, and re-exports only `LanguageModels`, with
  `@_exported public import LanguageModels`, so apps never import a format.
- A service whose models come from a list gets a case in `ModelCatalogGenerator`'s `CatalogSource`, which names it,
  says where its API lives and lists its vocabularies, and code that reads its list into the catalog's models, as
  `OpenRouterModelsResponse+Catalog.swift` does for OpenRouter. The generator then keeps a snapshot of the list in
  `Catalogs/<provider>.json`, and turns it into a static member and an effort type for each model, such as
  `Efforts.Of<OpenRouterCatalog.AnthropicClaudeHaiku5_5>`. The Model catalog workflow picks the new provider up with
  the others. A word the module's code names, such as a parameter a request sends, goes in the source's
  `wordsNamedByModule(in:)`, so a list that stops naming it doesn't deprecate its member and fail the build.
- The generator also writes `Generated/ModelRemovals+<Name>.swift`, with the models the provider stopped listing as
  `ModelRemovals.<name>`, where `<Name>` is the source's `swiftName`, such as `ModelRemovals.openRouter` in
  `ModelRemovals+OpenRouter.swift`. The details' `removalDate` returns `ModelRemovals.<name>.removalDate(of:)` for the
  model's id, as `OpenRouterModel` does; a provider without a catalog returns `nil`. Test that each removed model in
  the table has its `removalDate`, as `RemovalDateTests` does for OpenRouter.
- The module writes a `RequestExecutor` that conforms to `DetailedLanguageModelRequestExecutor`. The core's
  `DetailedLanguageModelExecutor` is always the model's executor: it logs an error and, in a debug build, shows a
  runtime warning for each removed model a request may reach, then calls the request executor's `execute`, which
  returns the answer's response text in a `DetailedLanguageModelAnswer`, or empty text when the answer ends in tool
  calls. For a request with a schema, the executor checks that text against the schema's guides and throws
  `GeneratedContent.ParsingError` when a value breaks one.
- Send requests through the module's API format, as [Where shared code goes](#where-shared-code-goes) describes, and
  build on the core's shared pieces rather than writing them again: `RequestAuthentication` for the auth closure,
  `ProviderHTTP` to send requests with the package's `User-Agent` and one gateway retry, `HTTPHeader`, `HTTPMethod` and
  `MediaType` for their names, `ServerSentEvent.Events` to read a stream, `InfoTransport` for cached info calls,
  `TranscriptTurn` and `AttachmentReader` to read the transcript, `Sampling` for the sampling settings and seed,
  `ListedParameters` to send only the settings every model lists, `ToolCallAssembler` for streamed tool calls,
  `TaggedReasoning` and `ReasoningOrigin` for reasoning entries, `LanguageModelError.ProviderFailure` for errors, and
  `OperationLog` for the log.
- Log through a `PackageLogger` with a category named after the module, which writes only at the levels the app's
  `LanguageModelsLogging.minimumLevel` lets through. Where the module works around a likely mistake, such as a setting
  the model doesn't take, log it at the info level and call `runtimeWarning(_:)`, which shows a runtime warning in a debug
  build.

## Where shared code goes

Code lives in the narrowest place that every user of it can reach:

- **The core, `LanguageModels`**, holds the public API and what any provider would use, whatever its API looks like:
  sending requests (`ProviderHTTP`, `ProviderConnection`), the requirements every format's dialect shares
  (`ProviderDialect`), failures as a provider's mapping reads them (`HTTPRejection`, `MappedError`), JSON and schemas
  (`JSONValue`, `JSONValueEncoder`, `portableSchema`), sampling, effort words, reasoning origins, errors and logging.
- **`APIFormat`** holds what the format targets share and provider modules never name: reading the transcript
  (`TranscriptTurn`, `AttachmentReader`) and streams (`ServerSentEvent`), assembling tool calls (`ToolCallAssembler`),
  reasoning a model writes in its answer's text (`TaggedReasoning`), the changes a request makes to what the app asked
  for (`RequestAdjustment`), request metadata within its limits, and the check for a host that rejects a schema's
  constraints. Provider modules never import it.
- **An API format target**, such as `ChatCompletionsAPI`, holds one format and nothing a provider adds to it. It isn't
  a product, it depends only on the core and `APIFormat`, and it offers providers, as `package`, only its dialect
  protocol, such as `ChatCompletionsDialect`, its one way in, `respond(to:model:streamingInto:as:)`, and the types its
  hooks take and return. Everything else in it, its executor included, is internal. Its tests use a dialect of their
  own, so they check the format alone.
- **A provider module** holds what only its service has: its public types, its catalog and info calls and its errors.
  Its dialect, in one folder named after the format, such as `ChatCompletions/`, conforms to the dialect protocol, and
  its request executor's `execute` there is one call into the format. No file outside that folder imports the format
  target.

A dialect names the provider, the model a request is for, its base URL and how requests reach it, and turns failures
into the provider's own public error. Every other hook has a default that keeps the format's behavior, so a service that
takes the format as OpenAI defines it writes only those. A dialect with more implements only what its service changes,
each with a typed value: its headers; its own members of the body as an `Encodable` type, their order, so the bytes a
host caches stay the same, and the members its models may not list; the attachments only it takes; the reasoning it
sends back; and what its chunks carry beyond the format's, as a `Decodable` type it reads into a state of its own. Each
hook receives a value only the format creates, holding just what that hook needs, and a dialect that sets a type
without the hook that uses it doesn't compile. Implement the hooks that have a default in the extension that declares
the conformance: only there does a misspelled hook draw a warning, which CI's `-warnings-as-errors` turns into an error,
instead of silently keeping its default.

The provider's own types, such as its model, errors, options and vocabularies, never name a format type; only its
dialect folder does, and so do only its tests in a test folder of the same name. Moving a provider to another format,
or picking one per model, then means writing a dialect for that format, and its public API stays the same. Give each
format its own `ReasoningOrigin`, since each sends reasoning back in another shape: reasoning a model wrote in one
format is then skipped, not sent back in the wrong one. Keep the values saved transcripts already hold, such as
`openrouter` for OpenRouter's Chat Completions reasoning.

Test a provider's requests and answers through Foundation Models, as `ExecutorExactExchangeTests` does: the bytes each
request sends and what the session's transcript holds afterwards. Test the dialect in the provider's test folder named
after the format, and the format's own behavior in the format's test target, so moving a provider to another format
doesn't rewrite its other tests.
