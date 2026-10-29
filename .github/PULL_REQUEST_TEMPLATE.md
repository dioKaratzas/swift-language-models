## What changed and why



## Checklist

- [ ] `swift format lint --strict -r Sources Tests Plugins Package.swift` passes.
- [ ] New behavior has tests; provider behavior has fixtures, and live tests where only a real model can show it.
- [ ] New public symbols have DocC comments.
- [ ] Generated files come from `ModelCatalogGenerator render`, not hand edits.
- [ ] A maintainer adds `release:patch`, `release:minor` or `release:major` to release this change on merge.
- [ ] With a release label, `UserAgent.packageVersion` is the version the merge tags, which the Release version check names.
