# Contributing

Issues and pull requests are welcome. For a larger change, such as a new provider module, open an issue first.

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

- `major` when a model loses effort levels or a generated member is deleted. The pull request also gets `needs-review`
  and waits for a maintainer.
- `minor` when a member is added, deprecated, marked unavailable or made available again, or a model gains effort
  levels.
- `patch` for any other change to a snapshot, such as a model's limits or parameters.
- No label when only the shape of a provider's API changed.

Any pull request but a major one merges once CI passes, and its label releases it.
[Model catalogs](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/modelcatalogs)
describes the same rules for the package's users.

## Add a provider module

A provider module is named `<Vendor>LanguageModels`, and its `<Vendor>LanguageModel` conforms to
`DetailedLanguageModel`. The article
[Writing a provider module](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/writingaprovider)
describes the model, its executor and what it reports. In this repository:

- Add the vendor's name to `providers` in `Package.swift`. That declares the module, its library product, and a test
  target that copies `Tests/<Vendor>LanguageModelsTests/Fixtures`, which you create. The module depends only on
  `LanguageModels`, and re-exports it with `@_exported public import LanguageModels`.
- A service whose models come from a list gets a case in `ModelCatalogGenerator`'s `CatalogSource`, which names it,
  says where its API lives and lists its vocabularies, and code that reads its list into the catalog's models, as
  `OpenRouterModelsResponse+Catalog.swift` does for OpenRouter. The generator then keeps a snapshot of the list in
  `Catalogs/<provider>.json`, and turns it into a static member for each model and into the effort types the models
  share. The Model catalog workflow picks the new provider up with the others.
- Send `UserAgent.current` as each request's `User-Agent`.
- Log through a `PackageLogger` with a category named after the module, which writes only at the levels the app's
  `LanguageModelsLogging.level` lets through. Where the module works around a likely mistake, such as a setting the
  model doesn't take, log it at the info level and call `runtimeWarning(_:)`, which shows a runtime warning in a debug
  build.
