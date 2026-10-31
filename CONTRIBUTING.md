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

## Add a provider module

A provider module is named `<Vendor>LanguageModels`, and its `<Vendor>LanguageModel` conforms to
`DetailedLanguageModel`. The article
[Writing a provider module](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/languagemodels/writingaprovider)
describes the model, its executor and what it reports. In this repository:

- Add the vendor's name to `providers` in `Package.swift`. That declares the module, its library product, and a test
  target that copies `Tests/<Vendor>LanguageModelsTests/Fixtures`, which you create. The module depends only on
  `LanguageModels`, and re-exports it with `@_exported public import LanguageModels`.
- A service whose models come from a list keeps a snapshot of it in `Catalogs/`, which the generator turns into a
  static member for each model and into the effort types the models share.
- Send `UserAgent.current` as each request's `User-Agent`.
- Log through a `PackageLogger` with a category named after the module, which writes only at the levels the app's
  `LanguageModelsLogging.level` lets through. Where the module works around a likely mistake, such as a setting the
  model doesn't take, log it at the info level and call `runtimeWarning(_:)`, which shows a runtime warning in a debug
  build.
