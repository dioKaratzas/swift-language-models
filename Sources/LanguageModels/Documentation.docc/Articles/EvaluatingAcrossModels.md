# Evaluating a feature across models

Measure how well a feature works with each model it can run on, with Apple's Evaluations framework.

## Overview

An evaluation runs a feature over a set of samples, scores each answer, and sums the scores up, so a change to a
prompt or a model shows up as a number. Apple's [Evaluations](https://developer.apple.com/documentation/evaluations)
framework ships with Xcode, next to Swift Testing. An `Evaluation` has four parts: a `dataset` of samples, a
`subject(from:)` that runs the feature for one sample, `evaluators` that score each answer as a `Metric`, and
`aggregateMetrics(using:)`, which sums the metrics up. Swift Testing runs it with the `.evaluates` trait.
[Evaluating language model responses](https://developer.apple.com/documentation/evaluations/evaluating-language-model-responses)
walks through each part.

The framework works with any model: the subject runs the feature with whatever model it's given, and a judge takes
`any LanguageModel`, so one evaluation measures Apple's on-device model and a provider module's model alike.

### Inject the model

The feature takes its model as a parameter, so the app passes the model it ships with, and an evaluation passes the
model it measures:

@Snippet(path: "swift-language-models/Snippets/CrossModelEvaluation", slice: "feature")

The evaluation keeps the model as `any LanguageModel`, and its `subject(from:)` calls the feature as the app does, so
it measures the code the app runs, instructions included:

@Snippet(path: "swift-language-models/Snippets/CrossModelEvaluation", slice: "evaluation")

### Run one test for each model

Each model gets a test of its own, because `.evaluates` takes one evaluation for the whole test function: a
parameterized test runs that same evaluation again for each argument. `.enabled(if:)` skips a test whose model can't
run, so a skipped test sends no requests. Apple's on-device model needs Apple Intelligence, and an OpenRouter model
needs its key, which a test reads from the environment. The test target imports `Evaluations`, `Testing` and the
provider module:

@Snippet(path: "swift-language-models/Snippets/CrossModelEvaluation", slice: "tests")

A sample whose `subject(from:)` throws, such as a request that hit a rate limit or timed out, is counted in
`result.errors.inferenceFailureCount` and left out of the score: three right answers and one failed request score
100%. When every sample fails, `aggregateValue(_:)` returns `-1`. So check the failure count next to the score, as
`check` does. An evaluator that fails, such as a judge whose model can't answer, shows up the same way, in
`evaluatorFailureCount` and `metricsNotFound`.

In the 27.2 SDK, an evaluation runs its samples one after another, so a run takes as long as all its requests
together. Xcode's documentation describes samples running concurrently, so don't depend on either.

### Label each run

The evaluation's `name` labels its run in Xcode's report and in the name of the results file, so it includes the
model's id. A slash in the name makes `swift test` name the file `untitled`, so the evaluation replaces it. Each key of
`info` becomes a column of the report: the model's id, and keys of your own, such as the prompt's version, which tell
runs apart after either changes. Apple's on-device model has no id and is updated with the OS, so its run records the
OS version. [Evaluating language model responses](https://developer.apple.com/documentation/evaluations/evaluating-language-model-responses)
shows the report in Xcode.

### Keep the results

`swift test` keeps attachments, such as each evaluation's result, only with `--attachments-path`, in a folder that
exists. It writes one `<name>.xcevalresult` file of JSON for each run, and passes the shell's environment, such as
`OPENROUTER_API_KEY`, to the tests:

```sh
mkdir -p results
swift test --attachments-path results
```

`xcodebuild test` keeps the results in its result bundle, and `xcresulttool` exports them. `xcodebuild` passes a test
only the environment variables whose names start with `TEST_RUNNER_`, without that prefix, as Xcode's
[environment variable reference](https://developer.apple.com/documentation/xcode/environment-variable-reference)
describes:

```sh
TEST_RUNNER_OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
    xcodebuild test -scheme MealPlanner -destination 'platform=macOS' -resultBundlePath run.xcresult
xcrun xcresulttool export evaluations --path run.xcresult --output-path results
```

`EvaluationResult.loadJSON(from:)` reads a stored run back. A result recorded with `recordTranscripts: true` holds
every prompt and answer, so keep it as private as the samples.

### Report a wrong answer

`logFeedbackAttachment(sentiment:issues:desiredResponseText:)` works on a session with any model, and returns JSON to
submit to Apple's Feedback Assistant. For another provider module's model, keep the prompt and the model's id
instead, and add the prompt as a sample of the evaluation's known failures, so every later run, with every model,
checks it.

### Profile with Instruments

Instruments' Foundation Models template records the sessions of any model, the package's included. It names a model
by its Swift type, such as `OpenRouterLanguageModel<HighMediumLowMinimal>`, without the model's id, so two OpenRouter
models look the same; profile one at a time.
[Analyzing the runtime performance of your Foundation Models app](https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app)
describes what it shows.

### Judges and repeatable runs

A model judge scores what code can't check, such as tone, and a remote model's answers vary from run to run. With
OpenRouter models:

- [Judging and generating samples](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/judgingandgeneratingsamples):
  choosing a judge from another model family, and generating samples with an OpenRouter model.
- [Repeatable runs](https://swiftpackageindex.com/dioKaratzas/swift-language-models/documentation/openrouterlanguagemodels/repeatableruns):
  pinning the model and host under test, and measuring how much answers vary.

To test the feature and the evaluation offline first, see <doc:TestingWithAScriptedModel>.

### Apple's guides

- [Evaluations](https://developer.apple.com/documentation/evaluations)
- [Designing effective evaluations](https://developer.apple.com/documentation/evaluations/designing-effective-evaluations)
- [Evaluating language model responses](https://developer.apple.com/documentation/evaluations/evaluating-language-model-responses)
- [Evaluating prompts to measure performance and improve model responses](https://developer.apple.com/documentation/foundationmodels/evaluating-prompts-to-measure-performance-and-improve-model-responses)
- [Designing specific, measurable criteria in an evaluation suite](https://developer.apple.com/documentation/evaluations/designing-evaluation-criteria)
- [Evaluation](https://developer.apple.com/documentation/evaluations/evaluation) and
  [EvaluationResult](https://developer.apple.com/documentation/evaluations/evaluationresult)
- [Evaluating a Core AI model](https://developer.apple.com/documentation/evaluations/evaluating-a-core-ai-model), a
  sample that evaluates a custom `LanguageModel` beside the default model
- [Book Tracker: Using Evaluations to evaluate an intelligent feature](https://developer.apple.com/documentation/evaluations/book-tracker-using-evaluations-to-evaluate-an-intelligent-feature)
- [Analyzing the runtime performance of your Foundation Models app](https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app)
- [Meet the Evaluations framework](https://developer.apple.com/videos/play/wwdc2026/298/), WWDC26
- [Improve your prompts by hill-climbing with Evaluations](https://developer.apple.com/videos/play/wwdc2026/335/),
  WWDC26
- [Debug and profile agentic app experiences with Instruments](https://developer.apple.com/videos/play/wwdc2026/243/),
  WWDC26
