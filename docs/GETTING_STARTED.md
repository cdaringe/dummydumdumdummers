# Getting Started

Install Thingfactory and run your first pipeline.

## Table of Contents

- [Getting Started](#getting-started)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Run an Example Pipeline](#run-an-example-pipeline)
  - [List Available Pipelines](#list-available-pipelines)
  - [Define Your Own Pipeline](#define-your-own-pipeline)
    - [Parallel Steps with Dependencies](#parallel-steps-with-dependencies)
    - [Steps with Loops](#steps-with-loops)
    - [Scheduled Pipelines](#scheduled-pipelines)
    - [Secrets](#secrets)
  - [Testing Pipelines](#testing-pipelines)
  - [Next Steps](#next-steps)

## Prerequisites

- [Gleam](https://gleam.run/getting-started/installing/) >= 1.13.0
- [Node.js](https://nodejs.org/) >= 22 (for JavaScript target)
- [Docker](https://docs.docker.com/get-docker/) (optional, for containerized execution)

## Installation

Clone and build:

```bash
git clone <repo-url> thingfactory
cd thingfactory
gleam build --warnings-as-errors
```

For the web GUI:

```bash
cd web
npm install
npm run dev
```

## Run an Example Pipeline

Run an example pipeline from the source file:

```bash
gleam run -m thingfactory/cli -- run -f src/thingfactory/examples.gleam basic_pipeline --isolator local
```

Run by runtime module reference:

```bash
gleam run -m thingfactory/cli -- run thingfactory@examples:basic_pipeline --isolator local
```

Compact mode (progress bar style):

```bash
gleam run -m thingfactory/cli -- run -f src/thingfactory/examples.gleam parallel_build_pipeline --isolator local -c
```

Interactive mode (drill into results after execution):

```bash
gleam run -m thingfactory/cli -- inspect -f src/thingfactory/examples.gleam artifact_sharing_pipeline
```

## List Available Pipelines

```bash
gleam run -m thingfactory/cli -- list
```

`list` prints usage patterns for runtime loading (`module:function` or `-f <file> <function>`), not embedded pipeline names.

## Define Your Own Pipeline

Create a new Gleam module:

```gleam
import gleam/dynamic
import thingfactory/pipeline
import thingfactory/executor
import thingfactory/types

pub fn my_pipeline() -> pipeline.Pipeline(dynamic.Dynamic) {
  pipeline.new("my_pipeline", "1.0.0")
  |> pipeline.add_step("fetch", fn(_ctx, _input) {
    Ok(dynamic.string("data from API"))
  })
  |> pipeline.add_step("process", fn(_ctx, data) {
    // Transform the data
    Ok(data)
  })
  |> pipeline.add_step("publish", fn(_ctx, processed) {
    Ok(dynamic.string("published"))
  })
}

pub fn run() -> types.ExecutionResult(dynamic.Dynamic) {
  executor.execute(my_pipeline(), dynamic.nil(), types.default_config())
}
```

### Parallel Steps with Dependencies

```gleam
pub fn my_parallel_pipeline() -> pipeline.Pipeline(dynamic.Dynamic) {
  pipeline.new("parallel_demo", "1.0.0")
  |> pipeline.add_step_with_deps("clone", clone_fn, [])
  |> pipeline.add_step_with_deps("lint", lint_fn, ["clone"])
  |> pipeline.add_step_with_deps("test", test_fn, ["clone"])
  |> pipeline.add_step_with_deps("build", build_fn, ["lint", "test"])
}
```

Steps `lint` and `test` run in parallel since both only depend on `clone`.

### Steps with Loops

```gleam
// Retry up to 3 times on failure
|> pipeline.add_step_with_loop("flaky_step", step_fn, types.RetryOnFailure(max_attempts: 3))

// Repeat exactly 5 times
|> pipeline.add_step_with_loop("batch", batch_fn, types.FixedCount(count: 5))

// Keep trying until success (max 10 attempts)
|> pipeline.add_step_with_loop("poll", poll_fn, types.UntilSuccess(max_attempts: 10))
```

### Scheduled Pipelines

```gleam
pipeline.new("nightly_build", "1.0.0")
|> pipeline.with_schedule(types.Daily(2, 0))  // 2:00 AM UTC daily
|> pipeline.add_step("build", build_fn)
```

### Secrets

```gleam
pipeline.new("deploy", "1.0.0")
|> pipeline.add_secret("API_KEY", "sk_live_...")
|> pipeline.add_step("deploy", fn(ctx, _input) {
  // Access secret via ctx.secret_store
  Ok(dynamic.string("deployed"))
})
```

## Testing Pipelines

Use mock steps for unit testing:

```gleam
import thingfactory/test_helpers

pub fn my_pipeline_test() {
  let mocks = [
    test_helpers.mock_step_success("fetch", dynamic.string("mock_data")),
    test_helpers.mock_step_error("process", types.StepFailure(message: "test error")),
  ]

  let result = test_helpers.run_with_mocks(my_pipeline(), mocks, dynamic.nil())

  // Assert on result.result, result.trace, etc.
}
```

Run tests:

```bash
gleam test
```

## Next Steps

- [Running Pipelines](RUNNING_PIPELINES.md) -- CLI output modes, artifact extraction, Docker
- [Web GUI Guide](WEB_GUI_GUIDE.md) -- visualize and monitor pipelines
- [Hosting the Service](HOSTING_SERVICE.md) -- deploy the web service
- See `src/thingfactory/examples.gleam` for 26 working pipeline examples
