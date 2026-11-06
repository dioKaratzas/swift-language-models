#!/usr/bin/env bash
# Builds the documentation site that GitHub Pages serves into ./site. Arguments go on to the documentation plugin.
set -euo pipefail

# Clients don't fetch the plugin: it is added to the manifest only here, for this build.
echo 'package.dependencies.append(.package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0"))' >> Package.swift

swift package --disable-sandbox --allow-writing-to-directory site generate-documentation \
  --target LanguageModels --target OpenRouterLanguageModels --target OpenAILanguageModels \
  --enable-experimental-combined-documentation \
  --transform-for-static-hosting --hosting-base-path swift-language-models \
  --output-path site "$@"

# The plugin exits with 0 even when merging the modules fails, which leaves no site.
test -f site/documentation/index.html

# DocC gives the site's root no page, so it sends visitors to the modules' landing page.
cat > site/index.html <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Swift Language Models</title>
<meta http-equiv="refresh" content="0; url=documentation/">
<link rel="canonical" href="documentation/">
<a href="documentation/">Documentation</a>
HTML
