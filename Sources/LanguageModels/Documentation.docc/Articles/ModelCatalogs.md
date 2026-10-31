# Model catalogs

See where a provider module's models come from, and how they change from one release to the next.

## Overview

A provider module whose service publishes a list of its models ships that list as a catalog. Each model is a static
member of the module's details type, such as `OpenRouterModel.anthropicClaudeHaiku5_5`, with its context size, output
limit, parameters, data kinds and reasoning levels. Its levels form the model's effort type, so
``DetailedLanguageModel/reasoningLevel(_:)`` offers only those, as <doc:ReasoningLevels> describes.

A catalog holds what changes rarely about a model. What changes often, such as prices and the health of each host,
a provider module reads from its service when you ask. A model that's newer than the catalog can still be described
by hand, with the initializer of the module's details type.

### How a catalog is made

The package's generator reads each service's model list and writes three things:

- A snapshot of the list, in `Catalogs/` in the package's repository.
- Each provider module's static members, and the words of its service's API, such as parameter names, in the module's
  `Generated/` folder.
- The effort types, which every provider module shares, under ``Efforts``.

A bot in the repository runs the generator for every service at once, and opens one pull request with the changes and
the release they need.

### How a model's member changes

| When the service | The catalog | Code that names the model |
|---|---|---|
| Lists a new model | Adds its static member | Can use it |
| Announces the day it retires a model | Marks the member `deprecated`, with that day | Compiles, with a warning that names the day |
| Stops listing a model | Keeps the member, marked `unavailable`, and leaves it out of the module's list of models and its lookup by id | Stops compiling, with "Removed from" and the service's name |
| Lists a dropped model again | Makes the member available again | Compiles again |
| Changes a model's limits, name, dates or parameters | Updates its data | Compiles unchanged |

The words of a service's API follow the same rules: a new word is added, and a word the service drops stays, marked
`unavailable`. So a catalog never deletes a member on its own.

### Which release a change needs

The package follows semantic versioning of its generated code:

- **Major:** a model loses reasoning levels, so its effort type changes, or a generated member is deleted.
- **Minor:** members are added, deprecated, marked unavailable or made available again, or a model gains reasoning
  levels. A member marked unavailable breaks code that names it, but the service no longer serves that model either.
- **Patch:** any other change to a catalog, such as a model's limits, name, dates or parameters.
- **None:** only the shape of the service's API changed, which changes no generated code.

Every provider module ships in one package, so one version covers every catalog: the release that one service's
changes need is a release of the whole package. A major release waits for a maintainer to review it; any other
release ships once the bot's pull request passes the package's tests.

Before version 1.0, a major release raises the minor version, such as from 0.3.2 to 0.4.0, and a dependency declared
with `from:` takes it. To take only patch releases until you choose to update, declare the dependency with
`.upToNextMinor(from:)`.
